#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

function reload_icinga2_local() {
    SERVICE="icinga2"

    echo "Reloading Icinga2 Local instance (if active)"
    systemctl is-active $SERVICE && systemctl reload $SERVICE
}

function reload_icinga2_shared() {
    SERVICE=icinga2-master

    echo "Reloading Icinga2 Shared instance (if active)"
    systemctl is-active $SERVICE && systemctl reload $SERVICE
}

function run_kickstart_wizard() {
    SERVICE="php-fpm"
    if systemctl is-active "$SERVICE" > /dev/null; then
        echo "Running Director Kickstart Wizard"
        icingacli director kickstart run
    else
        echo "Icingaweb2 is not active. Skipping Kickstart Wizard."
    fi
}

reload_icinga2_local

if [[ $neteye_deployment == 'single_node' ]]; then
    reload_icinga2_shared
    run_kickstart_wizard
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        reload_icinga2_shared
        run_kickstart_wizard
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