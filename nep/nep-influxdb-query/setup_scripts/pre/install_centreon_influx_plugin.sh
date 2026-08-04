#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
# Install RPM for InfluxDB Centreon Plugin
function install_plugin() {
    ddnf -y --enablerepo=centreon-*-stable*,epel install centreon-plugin-Applications-Databases-Influxdb
    if [ $? -eq 0 ]; then
        echo ' Done'
    else
        echo ' Unable to install RPM centreon-plugin-Applications-Databases-Influxdb'
        exit 1
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    install_plugin
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        install_plugin
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
    install_plugin
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255