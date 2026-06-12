#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

plugin_contrib_dir="/neteye/shared/monitoring/plugins"

function init_or_update_plugin_contrib_dir_local() {
    echo " - Updating Local Icinga2 instance"
    update_plugin_contrib_dir_definition local
}

function init_or_update_plugin_contrib_dir_shared() {
    SERVICE="icinga2-master"
    if systemctl is-active "$SERVICE" > /dev/null; then
        echo " - Updating Shared Icinga2 instance"
        update_plugin_contrib_dir_definition shared
    fi
}

function update_plugin_contrib_dir_definition {
    config_file="/neteye/$1/icinga2/conf/icinga2/constants.conf"

    sed -i 's|\s*const\s\s*PluginContribDir\s\s*=\s\s*"\s*"|const PluginContribDir = "'${plugin_contrib_dir}'"|g' ${config_file}
}

echo "[i] Updating PluginContribDir definition"
init_or_update_plugin_contrib_dir_local

if [[ $neteye_deployment == 'single_node' ]]; then
    init_or_update_plugin_contrib_dir_shared
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        init_or_update_plugin_contrib_dir_shared
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