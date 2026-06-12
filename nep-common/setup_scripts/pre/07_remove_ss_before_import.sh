#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

function remove_service_sets() {
    SERVICE="php-fpm"
    if systemctl is-active "$SERVICE" > /dev/null; then
        echo "[i] Prparing to update/rebuild Service Sets definitions"

        SQL="SELECT h.object_name AS 'Object Name', h.object_type AS 'Object Type' FROM icinga_service_set ssc INNER JOIN icinga_service_set_inheritance ssh ON ssh.service_set_id = ssc.id INNER JOIN icinga_service_set ssp ON ssh.parent_service_set_id = ssp.id INNER JOIN icinga_host h ON ssc.host_id = h.id WHERE ssc.object_name = "
        serviceset_objects=( "nx-ss-client-agent-windows-basic" "nx-ss-server-agent-windows-basic" "nx-ss-server-agent-linux-init" "nx-ss-server-agent-linux-systemd" "nx-ss-server-agent-linux-basic" )

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

    else
        echo "[i] Icingaweb2 is not active. Skipping."
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    remove_service_sets
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        remove_service_sets
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