#!/usr/bin/env bash

NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh

. /usr/share/neteye/scripts/rpm-functions.sh

neteye_is_ocs_unsupported() {
    local version
    version=$(sed -n 's/^NetEye release \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' /etc/neteye-release)
    [[ -n "$version" ]] && [[ "$(printf '%s\n' "$version" "4.48" | sort -V | head -n1)" == "4.48" ]]
}

remove_director_object() {
    local type="$1"
    local name="$2"
    if icingacli director "$type" exist "$name" >/dev/null 2>&1; then
        echo "[i] Removing legacy OCS Director object: $type '$name'"
        icingacli director "$type" delete "$name"
    fi
}

clean_import_baskets() {
    local import_dir="${NEP_STAGE_DIR}/${nep_name}/baskets/import"
    python3 - "$import_dir" <<'PY'
import json
import pathlib
import sys

import_dir = pathlib.Path(sys.argv[1])

for path in sorted(import_dir.glob("*.json")):
    with path.open(encoding="utf-8") as fh:
        data = json.load(fh)

    changed = False
    datalists = data.get("DataList", {})
    inventory = datalists.get("[NX] Inventory Command List")
    if inventory:
        entries = inventory.get("entries", [])
        filtered = [entry for entry in entries if entry.get("entry_name") != "ocs_duplicates"]
        if filtered != entries:
            inventory["entries"] = filtered
            changed = True

    servicesets = data.get("ServiceSet", {})
    asset_state = servicesets.get("nx-ss-neteye-asset-state")
    if asset_state:
        services = asset_state.get("services", {})
        for name in ("Asset Duplicates", "Asset Old not up-to-date", "Timer OCS GLPI full sync"):
            if name in services:
                del services[name]
                changed = True

    disk_state = servicesets.get("nx-ss-neteye-asset-disk-state")
    if disk_state:
        services = disk_state.get("services", {})
        for name in ("Disk OCS Reports Free space", "Disk OCS Server Free space"):
            if name in services:
                del services[name]
                changed = True

    if changed:
        with path.open("w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=4)
            fh.write("\n")
        print(f"[i] Removed legacy OCS objects from basket: {path}")
PY
}

if ! neteye_is_ocs_unsupported; then
    exit 0
fi

clean_import_baskets

if [[ $neteye_deployment == 'single_node' ]]; then
    remove_director_object command "nx-c-check_inventory"
    exit 0
fi

if [[ $neteye_deployment == 'cluster' && $neteye_node_type == 'node' ]]; then
    SERVICE="icingaweb2"
    if is_active "$SERVICE"; then
        remove_director_object command "nx-c-check_inventory"
    else
        echo "[i] Inactive Cluster Node. Skipping Director cleanup."
    fi
    exit 0
fi

exit 0
