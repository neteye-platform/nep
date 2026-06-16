#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function create_webhook_token() {
    PASSWORD_FILE=".pwd_webhook_nx_elastic_dataset"

    if [ ! -f "/root/${PASSWORD_FILE}" ] ; then
        generate_and_save_pw $PASSWORD_FILE
        echo "[i] Adding token on Tornado Webhook 'nx-elastic-dataset'"
    else
    echo "[i] Token already exist for Tornado Webhook 'nx-elastic-dataset'.. skip"
    fi

    # For Elasticsearch Transforms
    PASSWORD_FILE=".pwd_webhook_nx_elastic_transforms"

    if [ ! -f "/root/${PASSWORD_FILE}" ] ; then
        generate_and_save_pw $PASSWORD_FILE
        echo "[i] Adding token on Tornado Webhook 'nx-elastic-transforms'"
    else
    echo "[i] Token already exist for Tornado Webhook 'nx-elastic-transforms'.. skip"
    fi

    # For Elasticsearch Watchers
    PASSWORD_FILE=".pwd_webhook_nx_elastic_watchers"

    if [ ! -f "/root/${PASSWORD_FILE}" ] ; then
        generate_and_save_pw $PASSWORD_FILE
        echo "[i] Adding token on Tornado Webhook 'nx-elastic-watchers'"
    else
    echo "[i] Token already exist for Tornado Webhook 'nx-elastic-watchers'.. skip"
    fi

    # For EBP Verify
    PASSWORD_FILE=".pwd_webhook_nx_elproxy_verification"

    if [ ! -f "/root/${PASSWORD_FILE}" ] ; then
        generate_and_save_pw $PASSWORD_FILE
        echo "[i] Adding token on Tornado Webhook 'nx_elproxy_verification'"
    else
    echo "[i] Token already exist for Tornado Webhook 'nx_elproxy_verification'.. skip"
    fi

    exit 0
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_webhook_token
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="tornado_webhook_collector"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            create_webhook_token
        else
            echo "[i] Inactive Cluster Node. Skipping."
        fi

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