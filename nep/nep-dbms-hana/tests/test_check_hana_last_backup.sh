#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
PLUGIN="${REPO_ROOT}/nep/nep-dbms-hana/plugins/check_hana.sh"

TEST_TMP_DIR="$(mktemp -d)"
export TEST_TMP_DIR
LINK_CREATED=0
UTILS_LINK_CREATED=0

cleanup() {
  [[ "${LINK_CREATED}" == "1" ]] && rm -f /neteye/shared/monitoring/plugins/sap/hana/hdbclient
  [[ "${UTILS_LINK_CREATED}" == "1" ]] && rm -f /usr/lib64/neteye/monitoring/plugins/utils.sh
  rm -rf "${TEST_TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${TEST_TMP_DIR}/hdbclient" "${TEST_TMP_DIR}/plugins"
cat > "${TEST_TMP_DIR}/hdbclient/hdbclienv.sh" <<'EOF'
#!/bin/bash
EOF
chmod +x "${TEST_TMP_DIR}/hdbclient/hdbclienv.sh"

cat > "${TEST_TMP_DIR}/plugins/utils.sh" <<'EOF'
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
EOF

cat > "${TEST_TMP_DIR}/hdbclient/hdbsql" <<'EOF'
#!/bin/bash
set -euo pipefail

input_file=
output_file=
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -I) input_file="$2"; shift 2 ;;
    -o) output_file="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[[ -n "${input_file}" && -n "${output_file}" ]]
cp "${input_file}" "${TEST_TMP_DIR}/captured.sql"

case "${FAKE_MODE:-result}" in
  result)
    cat > "${output_file}" <<'EOF_OUTPUT'
"2026/09/23 12","any","any"," 123456","complete data backup","any","successful"," 1"," 0.00","AVG"," 1.00"," 100.00"," 1.00"," 0.10","any"
EOF_OUTPUT
    ;;
  empty) : > "${output_file}" ;;
  sql_error)
    echo '* 259: invalid table name' >&2
    exit 1
    ;;
  *) echo "Unknown fake mode: ${FAKE_MODE}" >&2; exit 1 ;;
esac
EOF
chmod +x "${TEST_TMP_DIR}/hdbclient/hdbsql"

mkdir -p /neteye/shared/monitoring/plugins/sap/hana
if [[ ! -e /neteye/shared/monitoring/plugins/sap/hana/hdbclient ]]; then
  ln -s "${TEST_TMP_DIR}/hdbclient" /neteye/shared/monitoring/plugins/sap/hana/hdbclient
  LINK_CREATED=1
fi

if [[ ! -e /usr/lib64/neteye/monitoring/plugins/utils.sh ]]; then
  mkdir -p /usr/lib64/neteye/monitoring/plugins
  ln -s "${TEST_TMP_DIR}/plugins/utils.sh" /usr/lib64/neteye/monitoring/plugins/utils.sh
  UTILS_LINK_CREATED=1
fi

run_plugin() {
  bash "${PLUGIN}" --sid HDB --host 127.0.0.1 --port 30013 --user SYSTEM --pass secret "$@"
}

assert_success_type() {
  local expected="$1"
  shift
  local output
  output="$(FAKE_MODE=result run_plugin --function last_backup --lookback 3 "$@")"
  [[ "${output}" == OK\ -* ]]
  grep -Fq "'${expected}' BACKUP_TYPE" "${TEST_TMP_DIR}/captured.sql"
}

assert_exit_output() {
  local expected_exit="$1"
  local expected_output="$2"
  local mode="$3"
  shift 3
  local output actual_exit
  set +e
  output="$(FAKE_MODE="${mode}" run_plugin "$@" 2>&1)"
  actual_exit=$?
  set -e
  [[ "${actual_exit}" -eq "${expected_exit}" ]]
  [[ "${output}" == *"${expected_output}"* ]]
}

bash -n "${PLUGIN}"

# Default compatibility and every supported explicit value.
assert_success_type "complete data backup"
assert_success_type "complete data backup" --backup-type "complete data backup"
assert_success_type "incremental data backup" --backup-type "incremental data backup"
assert_success_type "differential data backup" --backup-type "differential data backup"
assert_success_type "data snapshot" --backup-type "data snapshot"
assert_success_type "DATA_BACKUP" --backup-type DATA_BACKUP

# DATA_BACKUP must retain SAP's special four-type semantics in the SQL filter.
grep -Fq "BI.BACKUP_TYPE = 'DATA_BACKUP'" "${TEST_TMP_DIR}/captured.sql"
for type in "complete data backup" "differential data backup" "incremental data backup" "data snapshot"; do
  grep -Fq "'${type}'" "${TEST_TMP_DIR}/captured.sql"
done

assert_exit_output 3 "UNKNOWN: Invalid backup type: invalid" result \
  --function last_backup --lookback 3 --backup-type invalid
assert_exit_output 2 "No successful data backup found" empty \
  --function last_backup --lookback 3
assert_exit_output 2 "sql-statement failed:" sql_error \
  --function last_backup --lookback 3

# A non-last_backup function still runs its original SQL and ignores backup type.
assert_exit_output 0 "0 log_backups failed" empty \
  --function failed_log_backups --lookback 120 --backup-type invalid
grep -Fq "entry_type_name='log backup'" "${TEST_TMP_DIR}/captured.sql"

python3 - "${REPO_ROOT}/nep/nep-dbms-hana/baskets/import" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
load = lambda name: json.loads((root / name).read_text())

datalist = load("nep-dbms-hana-01-datalist.json")["DataList"]["[NX] SAP HANA Backup Type List"]
assert [entry["entry_value"] for entry in datalist["entries"]] == [
    "complete data backup",
    "incremental data backup",
    "differential data backup",
    "data snapshot",
    "DATA_BACKUP",
]

commands = load("nep-dbms-hana-03-command.json")
argument = commands["CommandTemplate"]["nx-ct-sap-check-hana"]["arguments"]["--backup-type"]
assert argument["value"] == "$nx_sap_hana_backup_type$"
assert "set_if" not in argument
assert commands["Command"]["nx-c-sap-check-hana-last-backup"]["imports"] == ["nx-ct-sap-check-hana"]

services = load("nep-dbms-hana-04-service.json")
field = next(value for value in services["Datafield"].values() if value["varname"] == "nx_sap_hana_backup_type")
assert field["settings"]["datalist"] == "[NX] SAP HANA Backup Type List"
assert any(item["datafield_id"] == 2053 for item in services["ServiceTemplate"]["nx-st-hana-last-backup"]["fields"])

service_sets = load("nep-dbms-hana-05-serviceset.json")["ServiceSet"]["nx-ss-hana-tenant-all"]["services"]
last_backup = next(service for service in service_sets if service["object_name"] == "HANA Last Backup")
assert last_backup["vars"]["nx_sap_hana_backup_type"] == "complete data backup"
PY

echo "NEP-912 HANA last_backup plugin tests: OK"
