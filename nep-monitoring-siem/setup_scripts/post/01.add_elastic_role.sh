#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function check_api_response {
  STATUS=$(echo $1 | jq 'select(.ErrorCode!=null).ErrorCode')
  RET=$2

  if [[ "$RET" -ne "0" ]]
  then
    echo "[!] curl returned exit code $RET"
    exit 1
  fi

  if [[ "$STATUS" -ne "200" ]]
  then
    echo "[!] Elasticsearch returned the following error:"
    echo $CURL_RAW_RESPONSE | jq 'select(.error!=null).error'
    exit 1
  fi
}

function add_elastic_role() {
  ES_CURL_DIR="/usr/share/neteye/elasticsearch/scripts/"
  QUERY_FILE="/tmp/role.json"
  ROLE_NAME="neteye_director_ingest_check"
  cat << EOF > "$QUERY_FILE"
{
    "cluster" : [ "manage_slm" ],
    "indices" : [
      {
        "names" : [
          "logs-*",
          "metrics-*",
          "logstash-*",
          "*beat-*"
        ],
        "privileges" : [
          "read",
          "monitor"
        ],
        "field_security" : {
          "grant" : [
            "*"
          ],
          "except" : [ ]
        },
        "allow_restricted_indices" : false
      }
    ],
    "applications" : [ ],
    "run_as" : [ ],
    "metadata" : { "owned_by": "NetEye" },
    "transient_metadata" : {
      "enabled" : true
    }
}
EOF

  CURL_RAW_RESPONSE="$(${ES_CURL_DIR}/es_curl.sh -sS -w '{"ErrorCode": %{http_code}}' -H 'Content-Type: application/json' -X PUT "https://elasticsearch.neteyelocal:9200/_security/role/${ROLE_NAME}" --data-binary "@${QUERY_FILE}")"

  check_api_response "$CURL_RAW_RESPONSE" "$?"
  echo "[i] Role added succesfully to Elastic '$ROLE_NAME'"

  ####
  ## Add role_mapping
  ####
  cat << EOF > "$QUERY_FILE"
{
    "enabled" : true,
    "roles" : [
      "$ROLE_NAME"
    ],
    "rules" : {
      "field" : {
        "username" : "NetEyeElasticCheck"
      }
    },
    "metadata" : { "owned_by": "NetEye" }
}
EOF

  CURL_RAW_RESPONSE="$(${ES_CURL_DIR}/es_curl.sh -sS -w '{"ErrorCode": %{http_code}}' -H 'Content-Type: application/json' -X PUT "https://elasticsearch.neteyelocal:9200/_security/role_mapping/${ROLE_NAME}" --data-binary "@${QUERY_FILE}")"

  check_api_response "$CURL_RAW_RESPONSE" "$?"
  echo "[i] Role mapping added succesfully to Elastic '$ROLE_NAME'"

  ####
  # Add fleet role
  ####
  ROLE_NAME="fleet_role"
  cat << EOF > "$QUERY_FILE"
{
    "cluster" : [ ],
    "indices" : [ ],
    "applications": [
      {
        "application": "kibana-.kibana",
        "privileges": [
          "feature_api.all",
          "feature_fleet.read",
          "feature_fleetv2.all",
          "feature_siem.minimal_read",
          "feature_siem.endpoint_list_read"
        ],
        "resources": [
          "*"
        ]
      }
    ],
    "run_as" : [ ],
    "metadata" : { "owned_by": "NetEye" },
    "transient_metadata" : {
      "enabled" : true
    }
}
EOF
  CURL_RAW_RESPONSE="$(${ES_CURL_DIR}/es_curl.sh -sS -w '{"ErrorCode": %{http_code}}' -H 'Content-Type: application/json' -X PUT "https://elasticsearch.neteyelocal:9200/_security/role/${ROLE_NAME}" --data-binary "@${QUERY_FILE}")"

  check_api_response "$CURL_RAW_RESPONSE" "$?"
  echo "[i] Role added succesfully to Elastic '$ROLE_NAME'"
}

if [[ $neteye_deployment == 'single_node' ]]; then
    add_elastic_role
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null; then
          add_elastic_role
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