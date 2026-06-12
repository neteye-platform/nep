#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

function install_grafana_plugins() {
    SERVICE="grafana-server"
    if systemctl is-active "$SERVICE" > /dev/null; then
        #Install Grafana Clock Panel plugin
        echo "Installing Grafana Plugins"

        GRAFANA_PLUGIN_DIR=/neteye/shared/grafana/data/plugins/
        PLUGIN_PATH=/tmp/grafana-plugin.zip

        echo "[i] Downloading Grafana Plugin"
        if [ -f ${PLUGIN_PATH} ]; then rm -f ${PLUGIN_PATH}; fi
        wget -O ${PLUGIN_PATH} https://grafana.com/api/plugins/grafana-clock-panel/versions/2.1.1/download

        echo "[i] Unpaking Grafana Plugin"
        unzip -o ${PLUGIN_PATH} -d ${GRAFANA_PLUGIN_DIR}/

        echo "[i] Removing temporary files"
        rm -f ${PLUGIN_PATH}

        # Restart of grafana-server is required.
        # It will be done in a post-setup step.
    else
        echo "[i] Grafana is not active. Skipping."
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    install_grafana_plugins
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        install_grafana_plugins
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