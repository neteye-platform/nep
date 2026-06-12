#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function webhook_update_pwd() {
    # For Elastic Dataset
    WEBHOOK_FILE="/neteye/shared/tornado_webhook_collector/conf/webhooks/nx-elastic-dataset.json"
    PASSWORD_FILE=".pwd_webhook_nx_elastic_dataset"

    PASSWORD=$(cat "/root/${PASSWORD_FILE}")
    PAYLOAD=$(cat "${WEBHOOK_FILE}")
    echo "${PAYLOAD}" | sed "s/@@PASSWORD@@/${PASSWORD}/g" > $WEBHOOK_FILE
    EXIT="$?"
    if [ "${EXIT}" -ne 0 ] ; then
        echo "  [-] Impossible to set the password for nx_elastic_dataset"
        exit 1
    fi

    # For Elastic Transforms
    WEBHOOK_FILE="/neteye/shared/tornado_webhook_collector/conf/webhooks/nx-elastic-transforms.json"
    PASSWORD_FILE=".pwd_webhook_nx_elastic_transforms"

    PASSWORD=$(cat "/root/${PASSWORD_FILE}")
    PAYLOAD=$(cat "${WEBHOOK_FILE}")
    echo "${PAYLOAD}" | sed "s/@@PASSWORD@@/${PASSWORD}/g" > $WEBHOOK_FILE
    EXIT="$?"
    if [ "${EXIT}" -ne 0 ] ; then
        echo "  [-] Impossible to set the password for nx_elastic_transforms"
        exit 1
    fi

    # For Elastic Watchers
    WEBHOOK_FILE="/neteye/shared/tornado_webhook_collector/conf/webhooks/nx-elastic-watchers.json"
    PASSWORD_FILE=".pwd_webhook_nx_elastic_watchers"

    PASSWORD=$(cat "/root/${PASSWORD_FILE}")
    PAYLOAD=$(cat "${WEBHOOK_FILE}")
    echo "${PAYLOAD}" | sed "s/@@PASSWORD@@/${PASSWORD}/g" > $WEBHOOK_FILE
    EXIT="$?"
    if [ "${EXIT}" -ne 0 ] ; then
        echo "  [-] Impossible to set the password for nx_elastic_watchers"
        exit 1
    fi

    # For EBP Verify (must create one for each blockchain in /etc/neteye-dpo)
    WEBHOOK_FILE="/neteye/shared/tornado_webhook_collector/conf/webhooks/elproxy_verification.json"
    PASSWORD_FILE=".pwd_webhook_nx_elproxy_verification"

    PASSWORD=$(cat "/root/${PASSWORD_FILE}")
    PAYLOAD=$(cat "${WEBHOOK_FILE}")
    echo "${PAYLOAD}" | sed "s/@@PASSWORD@@/${PASSWORD}/g" > $WEBHOOK_FILE
    EXIT="$?"
    if [ "${EXIT}" -ne 0 ] ; then
        echo "  [-] Impossible to set the password for nx_elproxy_verification"
        exit 1
    fi
}

# Restart Webhook Collector on a single node
function restart_webhook_collector() {
    echo "[i] Restart tornado_webhook_collector Service"
    systemctl restart tornado_webhook_collector.service
}

# Restart Webhook Collector on a cluster environment (needs to be launched where the service is active)
function restart_webhook_collector_on_cluster() {
    echo "[i] Unmanaging tornado_webhook_collector resource on PCS"
    PCS_RESOURCE_NAME=tornado_webhook_collector
    pcs resource unmanage $PCS_RESOURCE_NAME
    restart_webhook_collector
    echo "[i] Managing tornado_webhook_collector resource on PCS"
    pcs resource manage $PCS_RESOURCE_NAME
}

if [[ $neteye_deployment == 'single_node' ]]; then
    webhook_update_pwd
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="tornado_webhook_collector"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            webhook_update_pwd
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