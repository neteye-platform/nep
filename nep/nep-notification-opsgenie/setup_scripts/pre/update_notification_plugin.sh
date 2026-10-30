#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################

. /usr/share/neteye/scripts/rpm-functions.sh

## Copy (or update) OPSGenie/Jira Notification Plugin in to Icinga2 directories
## PREREQUISITE: Opsgenie Edger Connector and Jira Edge Connector must be installed on the system
# This kind of configuration must be performed only where Icinga2 Master is running
function update_notification_plugin() {
    OEC_PLUGIN_NAME=send2opsgenie
    JEC_PLUGIN_NAME=send2jsm
    OEC_RPM_BIN_PATH=/home/opsgenie/oec/opsgenie-icinga2/${OEC_PLUGIN_NAME}
    JEC_RPM_BIN_PATH=/home/jsm/jec/scripts/${JEC_PLUGIN_NAME}
    DESTINATION_PATH=/neteye/shared/icinga2/conf/icinga2/scripts

    echo "[i] Installing/updating OPSGenie/Jira notification plugin"

    if [ ! -d "${DESTINATION_PATH}" ]; then
        mkdir "${DESTINATION_PATH}"
        chown icinga.icinga "${DESTINATION_PATH}"
    fi

    /usr/bin/cp -f "${OEC_RPM_BIN_PATH}" "${DESTINATION_PATH}/"
    /usr/bin/cp -f "${JEC_RPM_BIN_PATH}" "${DESTINATION_PATH}/"
    chmod +x "${DESTINATION_PATH}/${OEC_PLUGIN_NAME}"
    chmod +x "${DESTINATION_PATH}/${JEC_PLUGIN_NAME}"
}

if [[ $neteye_deployment == 'single_node' ]]; then
    update_notification_plugin
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        DRBD_MOUNTPOINT="icinga2"
        if is_drbd_mounted  "$DRBD_MOUNTPOINT" ; then
            update_notification_plugin
        else
            echo "[i] Inactive Cluster Node, skipping autosetup"
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