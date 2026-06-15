#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function check_tornado_drafts() {
    DRAFT_PATH="/neteye/shared/tornado/conf/drafts/draft_001/config/master"
    RULES_PATH="/neteye/shared/tornado/conf/rules.d/master"

    if [ -d "$DRAFT_PATH" ]; then
        echo "[+] Add tornado rules to open draft"

        cp -pa  ${RULES_PATH}/nx_elastic_dataset $DRAFT_PATH
        cp -pa  ${RULES_PATH}/nx_elastic_transforms $DRAFT_PATH
        cp -pa  ${RULES_PATH}/nx_elastic_watchers $DRAFT_PATH
        cp -pa  ${RULES_PATH}/elproxy_verification $DRAFT_PATH
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    check_tornado_drafts
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="tornado"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            check_tornado_drafts
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