#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

# Path to file where SMS Notification settings should be placed
SMS_CONSTANTS_FILE_PATH=/neteye/shared/icinga2/conf/icinga2/conf.d/nx-constants-notification-sms.conf

function create_constants_file() {
    if [ -f ${SMS_CONSTANTS_FILE_PATH} ]; then
        echo "[i] SMS Constants file already exists. Skipping."
        return
    fi

    # Define a default constant file with only one (disabled) setting, which should be adapted by the user to fit their needs.
    echo '//const NxSmsdTargetServer = "<FQDN OF YOUR SMSD SERVER>"' > ${SMS_CONSTANTS_FILE_PATH}
    chown icinga:icinga ${SMS_CONSTANTS_FILE_PATH}
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_constants_file
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icinga2-master.service"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            create_constants_file
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