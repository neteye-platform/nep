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

function add_elastic_user() {
    ES_USERNAME="kibana_monitoring"
    PASSWORD_FILE="/root/.pwd_${ES_USERNAME}"
    save_password ".pwd_${ES_USERNAME}"

    if [ ! -f "${PASSWORD_FILE}" ] ; then
        echo "  [-] ${PASSWORD_FILE} for user ${ES_USERNAME} cannot be found"
        # should we continue with the next user instead?
        exit 1
    else
        echo "[i] Adding local user $ES_USERNAME into Elasticsearch"
    fi

    PASSWORD=$(cat "${PASSWORD_FILE}")
    PAYLOAD="""{
    \"password\": \"@@PASSWORD@@\",
    \"roles\": [
    \"fleet_role\"
    ]
}"""

    PAYLOAD_WITH_PWD=$(echo "${PAYLOAD}" | sed "s/@@PASSWORD@@/${PASSWORD}/g")
    EXIT="$?"
    if [ "${EXIT}" -ne 0 ] ; then
        echo "  [-] Impossible to set the password"
        exit 1
    fi

    CURL_OUT=$(/usr/share/neteye/elasticsearch/scripts/es_curl.sh -Ss -X POST "$ES_HOST:$ES_PORT/_security/user/${ES_USERNAME}" \
            -H 'Content-Type: application/json' -d "${PAYLOAD_WITH_PWD}" \
            -w "%{http_code}" \
            -o /dev/null)

    if [ "${CURL_OUT}" != "200" ]; then
        echo "[-] Cannot create ES user ${ES_USERNAME}, return code is ${CURL_OUT}"
        exit 1
    fi

    echo "[i] User ${ES_USERNAME} created successfully"


    ### Add user to fleet_scritp
    FILE_SCRIPT="/neteye/shared/monitoring/plugins/fleet-agent-status.sh"
    echo "[i] Add user ${ES_USERNAME} to script ${FILE_SCRIPT}"
    sed -i "s/@@PASSWORD@@/${PASSWORD}/g" $FILE_SCRIPT

    FILE_SCRIPT="/neteye/shared/monitoring/plugins/endpoint-agent-status.sh"
    echo "[i] Add user ${ES_USERNAME} to script ${FILE_SCRIPT}"
    sed -i "s/@@PASSWORD@@/${PASSWORD}/g" $FILE_SCRIPT
}

if [[ $neteye_deployment == 'single_node' ]]; then
    add_elastic_user
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            add_elastic_user
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