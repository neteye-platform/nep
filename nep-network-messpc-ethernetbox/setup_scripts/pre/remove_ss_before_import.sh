#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function remove_ss() {
    echo "[i] Prparing to update/rebuild Service Sets definitions"

    SQL="SELECT h.object_name AS 'Object Name', h.object_type AS 'Object Type' FROM icinga_service_set ssc INNER JOIN icinga_service_set_inheritance ssh ON ssh.service_set_id = ssc.id INNER JOIN icinga_service_set ssp ON ssh.parent_service_set_id = ssp.id INNER JOIN icinga_host h ON ssc.host_id = h.id WHERE ssc.object_name = "
    serviceset_objects=( "nx-ss-ethernetbox" "nx-ss-network-ethernetbox" )

    echo " - Checking direct assignment for Service Sets: ${serviceset_objects}"

    ## Delete service set objects
    for s in "${serviceset_objects[@]}"; do
        tmp=$(icingacli director serviceset exist "$s")
        if [[ $tmp != *"does not"* ]]; then
            ## Retrive manual usage of service set
            response=$(mysql -D director -e "$SQL'$s'")
            if [ -n "$response" ]; then
                echo "------------------------------------------------------------------------------------"
                echo "WARNING: Service Set '$s' assigned manually to these Director objects"
                mysql -D director -e "$SQL'$s'"
                echo "You have to add manually this Service Set and then deploy your configuration"
            fi
            ## Delete service set objects
            icingacli director serviceset delete "$s"
        fi
    done
}

if [[ $neteye_deployment == 'single_node' ]]; then
    remove_ss
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            remove_ss
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