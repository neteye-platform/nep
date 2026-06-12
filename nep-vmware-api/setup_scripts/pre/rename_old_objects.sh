#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function rename_old_objects() {
    declare -A command_objects
    command_objects["nx-c-check_vmware_snapshot"]="nx-c-check-vmware-snapshot"
    command_objects["nx-c-check_vmware_api"]="nx-c-check-vmware-api"
    command_objects["nx-c-check_vmware_api_datacenter"]="nx-c-check-vmware-api-datacenter"

    echo "Removing legacy Director Command Objects"

    ## Rename command objects
    for c in "${!command_objects[@]}"; do
        tmp=$(icingacli director command exist "$c")
        if [[ $tmp != *"does not"* ]]; then
            icingacli director command set "$c" --object_name "${command_objects[$c]}"
        fi
    done

    declare -A host_objects
    host_objects["nx-ht-vmware-host"]="nx-ht-vmware-api-host-system"
    host_objects["nx-ht-vmware-vm"]="nx-ht-vmware-api-virtual-machine"
    host_objects["nx-ht-vmware-vcenter"]="nx-ht-vmware-api-vcsa"

    echo "Removing legacy Director Host Objects"

    ## Re host objects
    for s in "${!host_objects[@]}"; do
        tmp=$(icingacli director host exist "$s")
        if [[ $tmp != *"does not"* ]]; then
            echo " - Removing legacy object ${s}"
            icingacli director host set "$s" --object_name "${host_objects[$s]}"
        fi
    done
}

if [[ $neteye_deployment == 'single_node' ]]; then
    rename_old_objects
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            rename_old_objects
        else
            echo "[i] Inactive Cluster Node. Skipping."
        fi

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