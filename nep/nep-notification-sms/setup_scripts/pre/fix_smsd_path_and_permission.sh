#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
smssend_dir="/neteye/local/smsd/data/spool"

function update_smssend_dir {
    config_file="/usr/bin/smssend"

    sed -i 's|/var/spool/sms/|'${smssend_dir}'|g' ${config_file}
}

function fix_smsd_path_and_permissions() {
    echo "Updating SMSd Spool definition"
    # Creating PluginContribDir

    if [ ! -d ${smssend_dir} ] ; then
        echo " - Creating SMSd Spool dir"
        mkdir -p ${smssend_dir}
    fi

    # Updating PluginContribDir on Icinga2 Local instance
    echo " - Updating Local SMSd instance"
    update_smssend_dir

    echo " - Updating Owner SMSd spool"
    chown icinga:icinga /neteye/local/smsd/data/spool/*
}

if [[ $neteye_deployment == 'single_node' ]]; then
    fix_smsd_path_and_permissions
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        fix_smsd_path_and_permissions
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