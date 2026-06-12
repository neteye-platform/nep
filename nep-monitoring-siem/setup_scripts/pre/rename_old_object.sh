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
    command_objects["nx-c-check_es_system"]="nx-c-check-es-system"
    command_objects["nx-c-check_filebeat"]="nx-c-check-filebeat"
    command_objects["nx-c-check_logstash"]="nx-c-check-logstash"
    command_objects["nx-c-check_logstash_queue"]="nx-c-check-logstash-queue"

    echo "Removing legacy Director Objects"

    ## Rename command objects
    for c in "${!command_objects[@]}"; do
        tmp=$(icingacli director command exist "$c")
        if [[ $tmp != *"does not"* ]]; then
            icingacli director command set "$c" --object_name "${command_objects[$c]}"
        fi
    done


    declare -A set_objects
    set_objects["nx-ss-neteye-siem-state"]="nx-ss-neteye-siem-units-state"
    set_objects["nx-ss-neteye-siem-clustered-state"]="nx-ss-neteye-siem-cluster-state"

    ## Rename serviceset objects
    for s in "${!set_objects[@]}"; do
        tmp=$(icingacli director serviceset exist "$s")
        if [[ $tmp != *"does not"* ]]; then
            icingacli director serviceset set "$s" --object_name "${set_objects[$s]}"
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