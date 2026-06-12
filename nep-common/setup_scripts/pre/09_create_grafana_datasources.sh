#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh
. /usr/share/neteye/secure_install/functions.sh
. /usr/share/neteye/grafana/scripts/grafana_autosetup_functions.sh

# This function wraps the CURL function to centralize the grafana API CURL standard params (default GET method)
# 1. Grafana API endpoint (i.e. "/api/admin/users")
# n. all params are forwarded to the curl function to grafana API
# Returns JSON response of Grafana API
# Returns int curl error
function gf_curl_put() {
    if [ -z "$GRAFANA_HOST" ] || [ -z "$GRAFANA_PORT" ]; then
        echo "[-] grafana host and/or port is not defined"
        exit 1
    fi
    if [ -z "$1" ]; then
        echo "[-] grafana API endpoint is missing"
        exit 2
    fi
    API_ENDPOINT="$1"
    shift
    RESULT="$(curl -sS "http://$GRAFANA_HOST:$GRAFANA_PORT/$API_ENDPOINT" \
        -X PUT \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json;charset=UTF-8' \
        -H 'X-WEBAUTH-USER: root' \
        "$@")"
    CURL_EXIT_CODE="$?"
    if [ "$CURL_EXIT_CODE" -ne 0 ] ; then
        echo "[-] Error: curl to grafana API failed (code: $CURL_EXIT_CODE)"
        return $CURL_EXIT_CODE
    fi
    echo "$RESULT"
}

# This function updates a grafana datasource definition
# 1. ID of the datasource
# 2. Name of the datasource
# 3. Configuration of the datasource (in json)
# 4. Hostname of the grafana server
# Returns 0 if the datasource was correctly updated
# Returns 1 if the datasource was not correctly updated
function update_datasource {
    if [ -z "$1" ]; then
        echo "[-] Name of the datasource is missing"
        exit 1
    fi

    if [ -z "$2" ]; then
        echo "[-] Configuration of the datasource is missing"
        exit 2
    fi

    DATASOURCE_ID="$1"
    DATASOURCE_NAME="$2"
    DATASOURCE_DATA="$3"
    HOST="$4"
    echo "[i] Updating '$DATASOURCE_NAME' grafana datasource ..."
    gf_curl_put "api/datasources/${DATASOURCE_ID}" \
        --data-binary "{$DATASOURCE_DATA}" > /dev/null

    if ! get_datasource_id "$DATASOURCE_NAME" "$HOST" >> /dev/null; then
        return 1
    fi
}

# This function prints the definition of the icinga-mysql datasource
# If an argument is provided (as arg1), it will be interpreted as the
# datasource's ID and added to the output.
# To work correctly, this function requires global variables.
# 1. ID of the datasource
function get_mysql_datasource_data {
    id=$1

    # Prepare parameters required for each Grafana API Call
    data="\"orgId\": 1"
    data="${data}, \"name\": \"${datasource_name}\""
    data="${data}, \"type\": \"mysql\""
    data="${data}, \"typeLogoUrl\": \"\""
    data="${data}, \"access\": \"proxy\""
    data="${data}, \"url\": \"mariadb.neteyelocal:3306\""
    data="${data}, \"password\": \"${mysql_password}\""
    data="${data}, \"user\": \"${mysql_username}\""
    data="${data}, \"database\": \"${mysql_database}\""
    data="${data}, \"basicAuth\": false"
    data="${data}, \"basicAuthUser\": \"\""
    data="${data}, \"basicAuthPassword\": \"\""
    data="${data}, \"withCredentials\": false"
    data="${data}, \"isDefault\": false"
    data="${data}, \"secureJsonData\": { \"password\":\"${mysql_password}\" }"
    data="${data}, \"readOnly\": false"

    # If the ID is provided, then the ID is put at the top of the parameters
    if [ ! -z $1 ]; then
        data="\"id\": $id, ${data}"
    fi

    echo "${data}"
}

function create_grafana_datasource() {

    SERVICE="grafana-server"
    if systemctl is-active "$SERVICE" > /dev/null; then
        echo "Creating Grafana Datasource to access IcingaDB Database"

        mysql_database='icingadb'
        mysql_username='icingadb_read_only'
        mysql_password_file="/root/.pwd_mariadb_icingadb_read_only"

        # Read password from Password File
        mysql_password="$(cat ${mysql_password_file})"

        # Defines some common variables
        datasource_name="icingadb-mysql"
        grafana_host="grafana.neteyelocal"

        echo " - Checking if datasource is present"
        # Check if the datasource already exists and gets its id
        datasource_id="$(get_datasource_id ${datasource_name})"

        # If the datasource does not exists is created anew
        # else, its current definition is forcefully updated
        if [ -z ${datasource_id} ]; then
            echo " - Creating new datasource"
            datasource_data="$(get_mysql_datasource_data)"
            create_datasource "${datasource_name}" "${datasource_data}" "${grafana_host}"
        else
            echo " - Datasource found. Restoring settings"
            datasource_data="$(get_mysql_datasource_data ${datasource_id})"
            update_datasource "${datasource_id}" "${datasource_name}" "${datasource_data}" "${grafana_host}"
        fi

    else
        echo "[i] Grafana is not active. Skipping."
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_grafana_datasource
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        create_grafana_datasource
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