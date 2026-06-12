#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
## Install and configure OpsGenie Edge Connector for NetEye
# This must be done on all cluster nodes (if is a cluster)
function install_oec_connector() {
    # Common variables
    OEC_NE_DIR=/neteye/local/oec
    OEC_NE_CFG_DIR=$OEC_NE_DIR/conf
    OEC_NE_LOG_DIR=$OEC_NE_DIR/log
    OEC_NE_SYS_DIR=$OEC_NE_DIR/conf/sysconfig
    OEC_USER=opsgenie
    OEC_GROUP=$OEC_USER
    OEC_UNIT_NAME=oec.service
    ICINGA_USER=icinga
    RPM_NAME='opsgenie-icinga2'
    RPM_URL='https://github.com/opsgenie/oec-scripts/releases/download/Icinga2-1.1.6_oec-1.1.3/opsgenie-icinga2-1.1.6.x86_64.rpm'


    ## To get the list of all available version, use https://github.com/atlassian/jsm-integration-scripts/releases
    echo "Installing/Updating OpsGenie integration with Icinga2"
    if (rpm -q $RPM_NAME > /dev/null); then
        echo "RPM $RPM_NAME already installed"
    else
        echo "Installing RPM $RPM_NAME"
        dnf -y install "$RPM_URL"

        echo "Stopping and disabling JEC Service"
        systemctl disable --now $OEC_UNIT_NAME
    fi

    if [ ! -d $OEC_NE_DIR ]; then
        echo 'Preparing basic configuration for OpsGenie Edge Connector/NetEye integration'

        # Create folders with the right permissions
        mkdir -p $OEC_NE_DIR
        mkdir -p $OEC_NE_CFG_DIR
        mkdir -p $OEC_NE_LOG_DIR
        mkdir -p $OEC_NE_SYS_DIR
        chown -R $OEC_USER.$OEC_GROUP $OEC_NE_DIR

        # Allow user icinga to access oec data
        usermod -a -G $OEC_GROUP $ICINGA_USER

    else
        echo 'OpsGenie Edge Connector already configured'
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    install_oec_connector
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        install_oec_connector
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