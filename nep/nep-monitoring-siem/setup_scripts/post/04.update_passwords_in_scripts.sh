#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh
. /usr/share/neteye/elasticsearch/scripts/es_autosetup_functions.sh

function update_passwords() {
    # Set username and get password from file
    ES_USERNAME="kibana_monitoring"
    echo "[i] Updating passwords in scripts for user ${ES_USERNAME}"
    PASSWORD_FILE="/root/.pwd_${ES_USERNAME}"
    PASSWORD=$(cat "${PASSWORD_FILE}")

    ### Set user and password into fleet script
    FILE_SCRIPT="/neteye/shared/monitoring/plugins/fleet-agent-status.sh"
    echo "[i] Add user ${ES_USERNAME} to script ${FILE_SCRIPT}"
    sed -i "s/@@PASSWORD@@/${PASSWORD}/g" $FILE_SCRIPT

    ### Set user and password into endpoint agent script
    FILE_SCRIPT="/neteye/shared/monitoring/plugins/endpoint-agent-status.sh"
    echo "[i] Add user ${ES_USERNAME} to script ${FILE_SCRIPT}"
    sed -i "s/@@PASSWORD@@/${PASSWORD}/g" $FILE_SCRIPT
}

if [[ $neteye_deployment == 'single_node' ]]; then
    update_passwords
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        update_passwords

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