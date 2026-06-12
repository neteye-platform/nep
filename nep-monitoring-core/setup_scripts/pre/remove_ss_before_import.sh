#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function remove_service_sets() {
    echo "Listing Service Set associations before updating"

    SQL="SELECT h.object_name AS 'Object Name', h.object_type AS 'Object Type' FROM icinga_service_set ssc INNER JOIN icinga_service_set_inheritance ssh ON ssh.service_set_id = ssc.id INNER JOIN icinga_service_set ssp ON ssh.parent_service_set_id = ssp.id INNER JOIN icinga_host h ON ssc.host_id = h.id WHERE ssc.object_name = "

    serviceset_objects=( "nx-ss-mysql-database-basic-performance" "nx-ss-mysql-dbms-basic-performance" "nx-ss-neteye-lampo-state" "nx-ss-neteye-mysql-dbms-basic-performance" "nx-ss-neteye-sms-state" "nx-ss-neteye-cluster-node-state" "nx-ss-neteye-core-cluster-state" "nx-ss-neteye-core-units-state" "nx-ss-neteye-endpoint-basic-performance" "nx-ss-neteye-endpoint-satellite-state" "nx-ss-neteye-icinga-instance-state" "nx-ss-neteye-icinga-agent-state" "nx-ss-neteye-endpoint-single-instance-performance" "nx-ss-neteye-linux-pcs-state" "nx-ss-neteye-core-state" "nx-ss-neteye-core-sms-state")

    echo "Removing direct Service Set assignment (if present) for these Service Sets: ${serviceset_objects}"

    for s in "${serviceset_objects[@]}"; do
        tmp=$(icingacli director serviceset exist "$s")
        if [[ $tmp != *"does not"* ]]; then
            response=$(mysql -D director -e "$SQL'$s'")
            if [ -n "$response" ]; then
                echo "------------------------------------------------------------------------------------"
                echo "Service Set: '$s' is assigned manually to the follwoing Director Objects"
                mysql -D director -e "$SQL'$s'"
                echo "WARNING: You have to add manually this Service Set to the object BEFORE deploy config"
            fi
            ## Delete service set objects
            icingacli director serviceset delete "$s"
        fi
    done
}

if [[ $neteye_deployment == 'single_node' ]]; then
    remove_service_sets
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            remove_service_sets
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