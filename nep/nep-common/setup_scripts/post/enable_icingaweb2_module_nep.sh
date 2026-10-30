#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function enable_icingaweb_module_nep() {
    echo 'Enabling NEP Module for Icingaweb2'

    SERVICE="php-fpm"
    if systemctl is-active "$SERVICE" > /dev/null ; then
        echo '[i] Enabling NEP Module for Icingaweb2'
        icingacli module enable nep
    else
        echo "[i] Icingaweb2 is not active. Skipping."
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    enable_icingaweb_module_nep
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        enable_icingaweb_module_nep
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