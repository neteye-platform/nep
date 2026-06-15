#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

function remove_old_objects() {
    SERVICE="php-fpm"
    if systemctl is-active "$SERVICE" > /dev/null; then
        host_objects=( "nx-ht-client-agent" "nx-ht-server-agent" )

        ## Delete host objects
        for s in "${host_objects[@]}"; do
            tmp=$(icingacli director host exist "$s")
            if [[ $tmp != *"does not"* ]]; then
                ## Delete service set objects
                icingacli director host delete "$s"
            fi
        done

    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    remove_old_objects
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        remove_old_objects
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