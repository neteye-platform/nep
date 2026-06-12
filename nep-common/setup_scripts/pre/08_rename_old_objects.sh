#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

function rename_objects() {
    SERVICE="php-fpm"
    if systemctl is-active "$SERVICE" > /dev/null; then
        declare -A service_objects
        service_objects["nx-st-agent-linux-init-state"]="nx-st-agent-linux-initd-service-state"
        service_objects["nx-st-agent-linux-unit-state"]="nx-st-agent-linux-systemd-unit-state"
        service_objects["nx-st-agent-linux-disk-space-usage"]="nx-st-agent-linux-disk-free-space"
        service_objects["nx-st-agent-linux-disk-freespace"]="nx-st-agent-linux-disk-free-space"
        service_objects["nx-st-agent-windows-disk-space-usage"]="nx-st-agent-windows-disk-free-space"

        echo "[i] Removing legacy Director Objects"

        ## Rename service set objects
        for s in "${!service_objects[@]}"; do
            tmp=$(icingacli director service exist "$s")
            if [[ $tmp != *"does not"* ]]; then
                echo " - Removing legacy object ${s}"
                icingacli director service set "$s" --object_name "${service_objects[$s]}"
            fi
        done
    else
        echo "[i] Icingaweb2 is not active. Skipping."
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    rename_objects
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        rename_objects
        exit 0
    fi
    if [[ $neteye_node_type == 'elastic_only' ]]; then
        exit 0
    fi
    if [[ $neteye_node_type == 'voting_only' ]]; then
        exit 0
    fi
fi
if [[ $neteye_deployment == 'satellite' ]]; then
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255