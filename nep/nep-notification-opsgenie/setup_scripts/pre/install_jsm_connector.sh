#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
## Install and configure Jira Edge Connector for NetEye
# This must be done on all cluster nodes (if is a cluster)
function install_jsm_connector() {
    # Common variables
    JEC_NE_DIR=/neteye/local/jec
    JEC_NE_CFG_DIR=$JEC_NE_DIR/conf
    JEC_NE_LOG_DIR=$JEC_NE_DIR/log
    JEC_NE_SYS_DIR=$JEC_NE_DIR/conf/sysconfig
    JEC_OUTPUT_DIR="jec/output"
    JEC_USER=jec
    JEC_GROUP=$JEC_USER
    JEC_UNIT_NAME=jec.service
    ICINGA_USER=icinga
    RPM_NAME='jsm-icinga2'
    RPM_URL='https://github.com/atlassian/jsm-integration-scripts/releases/download/icinga2-0.1.0_jec-0.1.0/jsm-icinga2-0.1.0.x86_64.rpm'


    ## To get the list of all available version, use https://github.com/atlassian/jsm-integration-scripts/releases
    echo "Installing/Updating JEC integration with Icinga2"
    if (rpm -q $RPM_NAME > /dev/null); then
        echo "RPM $RPM_NAME already installed"
    else
        echo "Installing RPM $RPM_NAME"
        dnf -y install "$RPM_URL"

        echo "Stopping and disabling JEC Service"
        systemctl disable --now $JEC_UNIT_NAME
    fi

    if [ ! -d $JEC_NE_DIR ]; then
        echo 'Preparing basic configuration for Jira Edge Connector/NetEye integration'

        # Create folders with the right permissions
        mkdir -p $JEC_NE_DIR
        mkdir -p $JEC_NE_CFG_DIR
        mkdir -p $JEC_NE_LOG_DIR
        mkdir -p $JEC_NE_SYS_DIR
        chown -R $JEC_USER.$JEC_GROUP $JEC_NE_DIR

        mkdir -p ~jec/$JEC_OUTPUT_DIR
        chown -R $JEC_USER.$JEC_GROUP ~jec/$JEC_OUTPUT_DIR

        # Allow user icinga to access jsm data
        usermod -a -G $JEC_GROUP $ICINGA_USER

    else
        echo 'Jira Edge Connector already configured'
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    install_jsm_connector
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        install_jsm_connector
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