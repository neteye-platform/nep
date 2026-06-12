#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

function add_entries_to_hosts() {
    ## Check and add if not exist service
    get_or_append_service_etchost "icingaweb2"
    get_or_append_service_etchost "snmptrapd"
    get_or_append_service_etchost "neteye"

    ## check if module is installed before insert
    if is_module_installed "neteye-siem"; then
        get_or_append_service_etchost "filebeat"
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    add_entries_to_hosts
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        add_entries_to_hosts
        exit 0
    fi
    if [[ $neteye_node_type == 'elastic_only' ]]; then
        add_entries_to_hosts
        exit 0
    fi
    if [[ $neteye_node_type == 'voting_only' ]]; then
        add_entries_to_hosts
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