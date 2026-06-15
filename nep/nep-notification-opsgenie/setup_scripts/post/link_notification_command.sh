#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
## Add Notification Plugin to Icinga2 Master Instance directories
## It is done by a symlink
# This kind of configuration must be performed only where Icinga2 Master is running
function link_notification_command() {
    OEC_USER=opsgenie
    OEC_GROUP=$OEC_USER
    JEC_USER=jec
    JEC_GROUP=$OEC_USER
    PLUGIN_BASE_PATH=/neteye/shared/icinga2/scripts
    OEC_PLUGIN_PATH=/neteye/shared/icinga2/scripts/opsgenie-icinga2
    JEC_PLUGIN_PATH=/neteye/shared/icinga2/scripts/jsm-opsgenie-icinga2

    echo '[i] Creating Icinga2 scripts folder'
    if [ ! -d "${PLUGIN_BASE_PATH}" ]; then
        mkdir $PLUGIN_BASE_PATH
    fi

    echo '[i] Creating symlink to Notification Script for Icinga2'
    if [ ! -d "${OEC_PLUGIN_PATH}" ]; then
        ln -s -f `eval echo ~${OEC_USER}`/oec/opsgenie-icinga2/send2opsgenie "${OEC_PLUGIN_PATH}"
    fi

    if [ ! -d "${JEC_PLUGIN_PATH}" ]; then
        ln -s -f `eval echo ~${JEC_USER}`/jec/scripts/send2jsm "${JEC_PLUGIN_PATH}"
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    link_notification_command
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icinga2-master"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            link_notification_command
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