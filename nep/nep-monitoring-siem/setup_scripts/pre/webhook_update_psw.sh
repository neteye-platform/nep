#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function update_webhook_password() {
    ## For Elastic Dataset Password
    PASSWORD_FILE=".pwd_webhook_nx_elastic_dataset"

    FILE="/usr/share/neteye/nep/nep-monitoring-siem/baskets/import/nep-monitoring-siem-05-serviceset.json"

    PASSWORD=$(cat "/root/${PASSWORD_FILE}")
    PAYLOAD=$(cat "${FILE}")
    echo "${PAYLOAD}" | sed "s/@@PASSWORD@@/${PASSWORD}/g" > $FILE
    EXIT="$?"
    if [ "${EXIT}" -ne 0 ] ; then
        echo "  [-] Impossible to set nx_elastic_dataset password"
        exit 1
    fi

    ## For Elastic Transforms Password
    PASSWORD_FILE=".pwd_webhook_nx_elastic_transforms"

    PASSWORD=$(cat "/root/${PASSWORD_FILE}")
    PAYLOAD=$(cat "${FILE}")
    echo "${PAYLOAD}" | sed "s/@@PASSWORD_TRANSFORMS@@/${PASSWORD}/g" > $FILE
    EXIT="$?"
    if [ "${EXIT}" -ne 0 ] ; then
        echo "  [-] Impossible to set nx_elastic_transforms password"
        exit 1
    fi

    ## For Elastic Watchers Password
    PASSWORD_FILE=".pwd_webhook_nx_elastic_watchers"

    PASSWORD=$(cat "/root/${PASSWORD_FILE}")
    PAYLOAD=$(cat "${FILE}")
    echo "${PAYLOAD}" | sed "s/@@PASSWORD_WATCHERS@@/${PASSWORD}/g" > $FILE
    EXIT="$?"
    if [ "${EXIT}" -ne 0 ] ; then
        echo "  [-] Impossible to set nx_elastic_watchers password"
        exit 1
    fi

    ## For EBP Verify
    PASSWORD_FILE=".pwd_webhook_nx_elproxy_verification"

    PASSWORD=$(cat "/root/${PASSWORD_FILE}")
    PAYLOAD=$(cat "${FILE}")
    echo "${PAYLOAD}" | sed "s/@@PASSWORD_EBP_VERIFY@@/${PASSWORD}/g" > $FILE
    EXIT="$?"
    if [ "${EXIT}" -ne 0 ] ; then
        echo "  [-] Impossible to set nx_elproxy_verification password"
        exit 1
    fi


    exit 0
}

if [[ $neteye_deployment == 'single_node' ]]; then
    update_webhook_password
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        update_webhook_password
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