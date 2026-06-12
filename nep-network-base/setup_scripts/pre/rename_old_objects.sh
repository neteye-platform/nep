#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh

##########################################
## Script main code: add your code here ##
##########################################
function rename_old_objects() {
    SERVICE="php-fpm"
    if systemctl is-active "$SERVICE" > /dev/null ; then
        declare -A command_objects
        command_objects["nx-c-check_nwc_health"]="nx-c-check-nwc-health"

        declare -A host_objects
        host_objects["nx-ht-snmp-network"]="nx-ht-network"
        host_objects["nx-ht-snmp-network-load-balancer"]="nx-ht-network-load-balancer"
        host_objects["nx-ht-snmp-network-wifi"]="nx-ht-network-wifi"
        host_objects["nx-ht-snmp-network-voip"]="nx-ht-network-voip"
        host_objects["nx-ht-snmp-network-firewall"]="nx-ht-network-firewall"
        host_objects["nx-ht-snmp-network-router"]="nx-ht-network-router"
        host_objects["nx-ht-snmp-network-switch"]="nx-ht-network-switch"

        declare -A serviceset_objects
        serviceset_objects["nx-ss-network-basic"]="nx-ss-network-snmp-basic"
        serviceset_objects["nx-ss-network-extra"]="nx-ss-network-snmp-extra"
        serviceset_objects["nx-ss-network-uptime"]="nx-ss-snmp-uptime"

        echo "Removing legacy Director Objects"

        ## Rename command objects
        for c in "${!command_objects[@]}"; do
            tmp=$(icingacli director command exist "$c")
            if [[ $tmp != *"does not"* ]]; then
                icingacli director command set "$c" --object_name "${command_objects[$c]}"
            fi
        done

        ## Rename host objects
        for h in "${!host_objects[@]}"; do
            tmp=$(icingacli director host exist "$h")
            if [[ $tmp != *"does not"* ]]; then
                icingacli director host set "$h" --object_name "${host_objects[$h]}"
            fi
        done

        ## Rename service set objects
        for s in "${!serviceset_objects[@]}"; do
            tmp=$(icingacli director serviceset exist "$s")
            if [[ $tmp != *"does not"* ]]; then
                icingacli director serviceset set "$s" --object_name "${serviceset_objects[$s]}"
            fi
        done
    else
        echo "[i] Icingaweb2 it no active. Skipping."
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    rename_old_objects
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        rename_old_objects
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