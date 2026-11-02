#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

function restart_grafana_via_systemctl() {
    echo "Restarting Grafana"

    SERVICE="grafana-server"
    if systemctl is-active "$SERVICE" > /dev/null; then
        echo " - Restarting unit grafana-server.service"
        systemctl restart grafana-server
    fi
}

function restart_grafana_via_pcs() {
    echo "Restarting Grafana"
    if is_cluster && is_drbd_mounted "grafana" ; then
        echo " - Performing cluster-controlled restart of Grafana"
        pcs resource restart grafana --wait=300
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    restart_grafana_via_systemctl
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        restart_grafana_via_pcs
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
