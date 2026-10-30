#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
SMSD_LOG_PATH=/neteye/local/smsd/log
LOG_FILE_OWNER=icinga
LOG_FILE_GROUP=icinga

function create_empty_log_files() {
    touch "${SMSD_LOG_PATH}/nx-notification.log"
    touch "${SMSD_LOG_PATH}/nx-notification-phone-ring.log"
    touch "${SMSD_LOG_PATH}/nx-notification-sms.log"

    chown ${LOG_FILE_OWNER}:${LOG_FILE_GROUP} "${SMSD_LOG_PATH}/nx-notification.log"
    chown ${LOG_FILE_OWNER}:${LOG_FILE_GROUP} "${SMSD_LOG_PATH}/nx-notification-phone-ring.log"
    chown ${LOG_FILE_OWNER}:${LOG_FILE_GROUP} "${SMSD_LOG_PATH}/nx-notification-sms.log"
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_empty_log_files
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        create_empty_log_files
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