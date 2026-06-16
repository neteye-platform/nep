#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
## Prepare configuration file template for JEC
## PREREQUISITE: Jira Edger Connector Password for Icinga must be created (during pre-setup phase)
# This kind of configuration must be performed on all cluster nodes
function configure_jec() {
    JEC_PWD_FILE=.pwd_icinga_jec
    JEC_CFG_TEMPLATE_FILE=/neteye/local/jec/conf/neteye-jec.json.tpl

    # Read Icinga2 API Password from file: it has been generated during pre-setup phase
    if [ -f "/root/$JEC_PWD_FILE" ]; then
        JEC_PWD=$(cat "/root/$JEC_PWD_FILE")
    else
        echo "Unable to read Jira Edge Connector password for Icinga"
        exit 1
    fi

    # Update password in JEC Configuration template file
    echo "Updating Configuration template file for Jira Edge Connector"
    template=$(jq " .\"globalFlags\".\"password\" = \"$JEC_PWD\"" $JEC_CFG_TEMPLATE_FILE)
    if [ "$?" == "0" ]; then
        echo "$template" > $JEC_CFG_TEMPLATE_FILE
    else
        echo "Unable to update Jira Edge Connector Template file"
        exit 1
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    configure_jec
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        configure_jec
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