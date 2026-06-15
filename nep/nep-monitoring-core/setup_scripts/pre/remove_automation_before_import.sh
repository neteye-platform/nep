#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function remove_automations() {
    ## Remove Sync Rules
    syncrule_objects=( "nx-sr-neteye-infrastructure-zones" "nx-sr-neteye-infrastructure-endpoints-update" "nx-sr-neteye-ip-duplicated-zones" "nx-sr-datalist-neteye-modules" )

    for s in "${syncrule_objects[@]}"; do
        tmp=$(icingacli nep syncrule list | grep "$s")
        if [[ $tmp != "" ]]; then
            ## Import Source exist
            echo " - Removing Sync Rule object: ${s}"
            id=$(echo $tmp | awk '{ print $1 }')
            icingacli nep syncrule delete --id $id
        fi
    done

    ## Remove Import Source
    importsource_objects=( "nx-is-neteye-infrastructure-endpoints" "nx-is-neteye-infrastructure-zones" "nx-is-datalist-neteye-modules" )

    for s in "${importsource_objects[@]}"; do
        tmp=$(icingacli nep importsource list | grep "$s")
        if [[ $tmp != "" ]]; then
            ## Import Source exist
            echo " - Removing Import Source object: ${s}"
            id=$(echo $tmp | awk '{ print $1 }')
            icingacli nep importsource delete --id $id
        fi
    done
}

if [[ $neteye_deployment == 'single_node' ]]; then
    remove_automations
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            remove_automations
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