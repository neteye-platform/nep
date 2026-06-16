#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################

. /usr/share/neteye/scripts/rpm-functions.sh

## Create and save a password used by Jira Edge Connector to access Icinga
# This kind of configuration must be performed only where Icinga2 Master is mounted
function create_icinga_password() {
    JEC_PWD_FILE=.pwd_icinga_jec
    if [ ! -f "/root/$JEC_PWD_FILE" ]; then
        echo "Generating Jira Edge Connector password for Icinga"
        generate_and_save_pw "$JEC_PWD_FILE"
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_icinga_password
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        DRBD_MOUNTPOINT="icinga2"
        if is_drbd_mounted  "$DRBD_MOUNTPOINT" ; then
            create_icinga_password
        else
            echo "[i] Inactive Cluster Node, skipping autosetup"
        fi

        exit 0
    fi
    if [[ $neteye_node_type == 'elastic_only' ]]; then
        # Place your code here
        exit 0
    fi
    if [[ $neteye_node_type == 'voting_only' ]]; then
        # Place your code here
        exit 0
    fi
fi
if [[ $neteye_deployment == 'satellite' ]]; then
    # Place your code here
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255