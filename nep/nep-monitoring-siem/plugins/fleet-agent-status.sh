#!/usr/bin/env bash
#################################################################
## Retrieve Elastic Agent status AND Agent Policies from       ##
## Kibana Fleet API in a single run (replaces                  ##
## fleet-agent-policies.sh).                                    ##
##                                                              ##
## Output (same directory as -f):                               ##
##  - elastic-agent_status.json + .d/          (global)         ##
##  - elastic-agent_status_<tenant>.json + .d/ (per tenant)     ##
##  - elastic-agent_policies.json              (global)         ##
##  - elastic-agent_policies_<tenant>.json     (per tenant)     ##
##                                                              ##
## Tenant = Kibana space prefix "<code>_" (xxxxxx_elk -> xxxxxx)##
## or explicit mapping (config file -c, or option -m).          ##
## Nothing is published unless ALL API calls succeed.           ##
#################################################################

DEFAULT_FILE="/neteye/shared/icinga2/data/lib/icinga2/elastic-agent_status.json"
POLICIES_PREFIX="elastic-agent_policies"

# Space ID -> tenant: "<code>_<anything>" => <code>; otherwise the space ID itself
TENANT_REGEX='^([[:digit:]]+)_.+$'

# Explicit space -> tenant mapping for spaces without "<code>_" prefix
# (e.g. the Kibana "default" and "master" spaces). Empty by default: an
# unmapped space is its own tenant, so nothing is merged by accident.
# Fill it from the config file (-c) and/or with -m; see print_help.
declare -A SPACE_TENANT_MAP=()
CONF_FILE_DEFAULT="/neteye/shared/monitoring/conf/fleet-agent-status.conf"
MAP_OPT=""
WARNINGS=()

print_help() {
    echo ""
    echo "This script retrieves Elastic Agent status and Agent Policies by Kibana Fleet API"
    echo "and writes global and per-tenant JSON files."
    echo ""
    echo "Usage:"
    echo "-h"
    echo "-f <file_path>    [optional]    ... file path of global status JSON (default: $DEFAULT_FILE)"
    echo "                                    all other files are written in the same directory"
    echo "-S                [optional]    ... Enable SSL (auto-enabled if Kibana answers only on HTTPS)"
    echo "-c <conf_file>    [optional]    ... space -> tenant mapping file (default: $CONF_FILE_DEFAULT)"
    echo "                                    one \"<space>=<tenant>\" per line, # for comments;"
    echo "                                    ignored if the default file does not exist"
    echo "-m <map>          [optional]    ... space -> tenant mapping, e.g. -m default=123456,master=123456"
    echo "                                    overrides the config file"
    echo "-z                [optional]    ... Allow empty results (0 agents or 0 policies)"
    echo "                                    default: an empty result is treated as an error"
    echo "-P                [deprecated]  ... Ignored (policies are always exported)"
    exit 0
}

# --- Read options
while getopts "hf:SzPc:m:" opt; do
    case "${opt}" in
        f) JSON_FILE=${OPTARG} ;;
        S) ssl_enabled=1 ;;
        z) allow_empty=1 ;;
        c) CONF_FILE=${OPTARG} ;;
        m) MAP_OPT=${OPTARG} ;;
        P) ;;   # deprecated, ignored: kept so existing commands with -P keep working
        h|*) print_help ;;
    esac
done

JSON_FILE="${JSON_FILE:-$DEFAULT_FILE}"
OUT_DIR=$(dirname "$JSON_FILE")
STATUS_BASE="${JSON_FILE%.json}"        # e.g. .../elastic-agent_status

####### CONFIG #############
KBN_USER="kibana_monitoring"
KBN_PASSWORD="@@PASSWORD@@"
PER_PAGE=200
CURL_TIMEOUT=60

# add_mapping <space> <tenant> <origin>: validates and stores one mapping
add_mapping() {
    local sp="$1" tn="${2,,}"
    if [[ ! "$sp" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ || ! "$tn" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
        WARNINGS+=("Ignored invalid mapping '$sp=$2' ($3)")
        return
    fi
    SPACE_TENANT_MAP[$sp]="$tn"
}

# Mapping file: plain "<space>=<tenant>" lines, parsed (never sourced).
# -c must exist; the default file is optional.
if [ -n "$CONF_FILE" ]; then
    [ -r "$CONF_FILE" ] || { echo "CRITICAL - Mapping file not readable: $CONF_FILE"; exit 2; }
elif [ -r "$CONF_FILE_DEFAULT" ]; then
    CONF_FILE="$CONF_FILE_DEFAULT"
fi
if [ -n "$CONF_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [ -z "$line" ] && continue
        if [[ "$line" == *=* ]]; then
            add_mapping "${line%%=*}" "${line#*=}" "$CONF_FILE"
        else
            WARNINGS+=("Ignored invalid line '$line' in $CONF_FILE")
        fi
    done < "$CONF_FILE"
fi

# -m overrides the file
if [ -n "$MAP_OPT" ]; then
    IFS=',' read -ra PAIRS <<< "$MAP_OPT"
    for pair in "${PAIRS[@]}"; do
        if [[ "$pair" == *=* ]]; then
            add_mapping "${pair%%=*}" "${pair#*=}" "-m"
        else
            WARNINGS+=("Ignored invalid mapping '$pair' (-m)")
        fi
    done
fi

if [[ $ssl_enabled -eq 1 ]]; then
    KBN_URL="https://kibana.neteyelocal:5601"
else
    KBN_URL="http://kibana.neteyelocal:5601"
fi

# Work dir on the same filesystem as the output => every mv is atomic
WORK_DIR=$(mktemp -d "${OUT_DIR}/.fleet-agent-status.XXXXXX") || {
    echo "CRITICAL - Unable to create work directory in $OUT_DIR"; exit 2; }
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
    echo "CRITICAL - $*; keeping previous data"
    exit 2
}

####### FUNCTIONS #############

# kbn_get <space_id> <api_path_with_query> <out_file>
# Writes the body to <out_file>; returns 0 only on HTTP 200 with valid JSON.
kbn_get() {
    local space="$1" path="$2" out="$3" base code
    if [[ "$space" == "default" ]]; then
        base="$KBN_URL"
    else
        base="$KBN_URL/s/$space"
    fi

    code=$(/usr/bin/curl -u "${KBN_USER}:${KBN_PASSWORD}" \
        -XGET -H 'kbn-xsrf: true' \
        -sS --max-time "$CURL_TIMEOUT" \
        -o "$out" -w '%{http_code}' \
        "${base}${path}" 2>"$WORK_DIR/curl.err") || code="${code:-000}"

    KBN_CODE="$code"
    KBN_ERR=""

    if [[ "$code" != "200" ]]; then
        KBN_ERR="Kibana API error (HTTP $code) on space '$space' path ${path%%\?*}: $(error_reason "$out")"
        return 1
    fi

    if ! jq empty "$out" 2>/dev/null; then
        KBN_ERR="Invalid JSON from Kibana on space '$space' path ${path%%\?*}"
        return 1
    fi
}

# error_reason <body_file>
# One-line, human readable reason: transport error, JSON message, or HTML title.
error_reason() {
    local body="$1" r=""
    if [ -s "$WORK_DIR/curl.err" ]; then
        r=$(head -n 1 "$WORK_DIR/curl.err" | sed 's/^curl: ([[:digit:]]*) *//')
    fi
    if [ -z "$r" ] && [ -s "$body" ]; then
        r=$(jq -r '.message // .error // empty' "$body" 2>/dev/null | head -n 1)
        [ -z "$r" ] && r=$(tr '\n' ' ' < "$body" | sed -n 's/.*<title>\([^<]*\)<\/title>.*/\1/p')
        [ -z "$r" ] && r=$(head -c 150 "$body" | tr '\n' ' ')
    fi
    r="${r%"${r##*[![:space:]]}"}"          # trim trailing blanks
    [ -z "$r" ] && r="no response"
    printf '%s' "${r:0:150}"
}

# fetch_paged <space_id> <endpoint> <ndjson_out>
# Iterates all pages of a Fleet list endpoint and writes one item per line.
fetch_paged() {
    local space="$1" endpoint="$2" out="$3"
    local page=1 pages=1 total resp="$WORK_DIR/response.json"

    : > "$out"
    while :; do
        kbn_get "$space" "${endpoint}?perPage=${PER_PAGE}&page=${page}" "$resp" || return 1
        jq -c '.items[]?' "$resp" >> "$out" || {
            KBN_ERR="Unable to parse items from space '$space' path $endpoint"; return 1; }

        if (( page == 1 )); then
            total=$(jq -r '.total // 0' "$resp")
            [[ "$total" =~ ^[[:digit:]]+$ ]] || total=0
            pages=$(( (total + PER_PAGE - 1) / PER_PAGE ))
        fi

        (( page >= pages )) && break
        page=$((page + 1))
    done
}

# space_to_tenant <space_id>
space_to_tenant() {
    if [[ -n "${SPACE_TENANT_MAP[$1]}" ]]; then
        echo "${SPACE_TENANT_MAP[$1]}"
    elif [[ "$1" =~ $TENANT_REGEX ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$1"
    fi
}

# build_status <agents_ndjson> <json_out> <cache_dir_out>
# Deduplicates agents by id and builds the per-host cache.
build_status() {
    local src="$1" json="$2" cache="$3" map="$WORK_DIR/cache_map.tsv" host b64

    jq -s 'unique_by(.id)' "$src" > "$json" || return 1

    jq -r '
        .[]
        | select((.local_metadata.host.hostname // "") != "")
        | [(.local_metadata.host.hostname | ascii_downcase), (@base64)]
        | @tsv
    ' "$json" > "$map" || return 1

    mkdir -p "$cache" || return 1
    while IFS=$'\t' read -r host b64; do
        [[ "$host" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || continue
        printf '%s' "$b64" | base64 -d >> "$cache/$host"
        printf '\n' >> "$cache/$host"
    done < "$map"

    chmod 0644 "$json" && chmod 0755 "$cache" && \
        find "$cache" -type f -exec chmod 0644 {} +
}

# build_policies <policies_ndjson> <json_out>
build_policies() {
    jq -s 'unique_by(.id)' "$1" > "$2" && chmod 0644 "$2"
}

# publish_status <json_tmp> <json_dest> <cache_tmp> <cache_dest>
publish_status() {
    local json_tmp="$1" json_dest="$2" cache_tmp="$3" cache_dest="$4"
    local cache_old="${cache_dest}.old"

    if ! mv "$json_tmp" "$json_dest"; then
        echo "CRITICAL - Unable to publish $json_dest"
        return 1
    fi

    rm -rf "$cache_old"
    if [ -d "$cache_dest" ] && ! mv "$cache_dest" "$cache_old"; then
        echo "CRITICAL - Unable to preserve previous cache $cache_dest"
        return 1
    fi

    if ! mv "$cache_tmp" "$cache_dest"; then
        echo "CRITICAL - Unable to publish new cache $cache_dest"
        [ -d "$cache_old" ] && mv "$cache_old" "$cache_dest"
        return 1
    fi

    rm -rf "$cache_old"
}

# publish_file <tmp> <dest>
publish_file() {
    mv "$1" "$2" || { echo "CRITICAL - Unable to publish $2"; return 1; }
}

####### MAIN #############

# --- Get spaces (must succeed and return at least one space)
if ! kbn_get "default" "/api/spaces/space" "$WORK_DIR/spaces.json"; then
    # Auto-switch to HTTPS when Kibana answers only on HTTPS and -S was not given
    if [[ "$KBN_CODE" == "400" && "$KBN_URL" == http://* ]] \
       && grep -qi 'https port' "$WORK_DIR/spaces.json" 2>/dev/null; then
        KBN_URL="https://${KBN_URL#http://}"
        kbn_get "default" "/api/spaces/space" "$WORK_DIR/spaces.json" || fail "$KBN_ERR"
    else
        fail "$KBN_ERR"
    fi
fi
mapfile -t SPACE_IDS < <(jq -r '.[]?.id // empty' "$WORK_DIR/spaces.json")
[ ${#SPACE_IDS[@]} -gt 0 ] || fail "No Kibana spaces returned"

# --- Mapping sanity checks (warnings only)
for MAP_SPACE in "${!SPACE_TENANT_MAP[@]}"; do
    MAP_TENANT="${SPACE_TENANT_MAP[$MAP_SPACE]}"
    FOUND_SPACE=0; FOUND_PREFIX=0
    for S in "${SPACE_IDS[@]}"; do
        [[ "$S" == "$MAP_SPACE" ]] && FOUND_SPACE=1
        [[ "$S" == "${MAP_TENANT}_"* ]] && FOUND_PREFIX=1
    done
    (( FOUND_SPACE )) || WARNINGS+=("Mapping for unknown space '$MAP_SPACE' (tenant $MAP_TENANT)")
    (( FOUND_SPACE && ! FOUND_PREFIX )) && \
        WARNINGS+=("Space '$MAP_SPACE' is mapped to tenant '$MAP_TENANT' but no '${MAP_TENANT}_*' space exists: check the mapping")
done

ALL_AGENTS="$WORK_DIR/all_agents.ndjson"
ALL_POLICIES="$WORK_DIR/all_policies.ndjson"
: > "$ALL_AGENTS"
: > "$ALL_POLICIES"
declare -A TENANTS=()

# --- Phase 1: fetch agents and policies of every space (nothing published yet)
for SPACE_ID in "${SPACE_IDS[@]}"; do
    SD="$WORK_DIR/space_${SPACE_ID//[^a-zA-Z0-9_-]/_}"
    mkdir -p "$SD"

    fetch_paged "$SPACE_ID" "/api/fleet/agents" "$SD/agents.ndjson" || fail "$KBN_ERR"
    fetch_paged "$SPACE_ID" "/api/fleet/agent_policies" "$SD/policies.ndjson" || fail "$KBN_ERR"

    cat "$SD/agents.ndjson"   >> "$ALL_AGENTS"
    cat "$SD/policies.ndjson" >> "$ALL_POLICIES"

    TENANT_ID=$(space_to_tenant "$SPACE_ID")
    if [[ ! "$TENANT_ID" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
        WARNINGS+=("Tenant '$TENANT_ID' (space '$SPACE_ID') not usable as file name; included only in global files")
        continue
    fi

    TD="$WORK_DIR/tenant_${TENANT_ID}"
    mkdir -p "$TD"
    cat "$SD/agents.ndjson"   >> "$TD/agents.ndjson"
    cat "$SD/policies.ndjson" >> "$TD/policies.ndjson"
    TENANTS[$TENANT_ID]+="$SPACE_ID "
done

# --- Phase 2: build global files
build_status "$ALL_AGENTS" "$WORK_DIR/global.json" "$WORK_DIR/global_cache" \
    || fail "Failed to build aggregated status JSON"
build_policies "$ALL_POLICIES" "$WORK_DIR/global_policies.json" \
    || fail "Failed to build aggregated policies JSON"

TOTAL_HOSTS=$(jq 'length' "$WORK_DIR/global.json")
TOTAL_POLICIES=$(jq 'length' "$WORK_DIR/global_policies.json")

# A working Fleet always has agents and policies: empty results mean something is wrong
if [[ $allow_empty -ne 1 ]]; then
    [[ "$TOTAL_HOSTS" -gt 0 ]]    || fail "Kibana returned 0 agents in ${#SPACE_IDS[@]} space(s)"
    [[ "$TOTAL_POLICIES" -gt 0 ]] || fail "Kibana returned 0 agent policies in ${#SPACE_IDS[@]} space(s)"
fi

# --- Phase 3: build per-tenant files
mapfile -t TENANT_LIST < <(printf '%s\n' "${!TENANTS[@]}" | sort)
PERFDATA_TENANTS=""

for TENANT_ID in "${TENANT_LIST[@]}"; do
    TD="$WORK_DIR/tenant_${TENANT_ID}"
    build_status "$TD/agents.ndjson" "$TD/status.json" "$TD/cache" \
        || fail "Failed to build status JSON for tenant $TENANT_ID"
    build_policies "$TD/policies.ndjson" "$TD/policies.json" \
        || fail "Failed to build policies JSON for tenant $TENANT_ID"
    PERFDATA_TENANTS="$PERFDATA_TENANTS 'hosts_${TENANT_ID}'=$(jq 'length' "$TD/status.json");;;0;"
done

# --- Phase 4: publish (only reached if everything above succeeded)
publish_status "$WORK_DIR/global.json" "$JSON_FILE" \
               "$WORK_DIR/global_cache" "${STATUS_BASE}.d" || exit 2
publish_file "$WORK_DIR/global_policies.json" "${OUT_DIR}/${POLICIES_PREFIX}.json" || exit 2

for TENANT_ID in "${TENANT_LIST[@]}"; do
    TD="$WORK_DIR/tenant_${TENANT_ID}"
    publish_status "$TD/status.json" "${STATUS_BASE}_${TENANT_ID}.json" \
                   "$TD/cache" "${STATUS_BASE}_${TENANT_ID}.d" || exit 2
    publish_file "$TD/policies.json" "${OUT_DIR}/${POLICIES_PREFIX}_${TENANT_ID}.json" || exit 2
done

echo "OK - Exported $TOTAL_HOSTS unique agent(s) and $TOTAL_POLICIES unique policies from ${#SPACE_IDS[@]} space(s), ${#TENANT_LIST[@]} tenant(s).|hosts=$TOTAL_HOSTS;;;0; policies=$TOTAL_POLICIES;;;0;$PERFDATA_TENANTS"
if [ ${#WARNINGS[@]} -gt 0 ]; then
    for W in "${WARNINGS[@]}"; do
        echo "WARNING - $W"
    done
fi
exit 0
