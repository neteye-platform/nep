#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
###############
#### Add user for API monitoring
###############
## NOTE work only from neteye 4.25
function add_api_user() {
  API_NAME="icinga-monitoring"
  FILE=/neteye/shared/icinga2/conf/.elastic_api_key
  JSON_INPUT='
{
  "name": "'${API_NAME}'",
  "role_descriptors": {
    "monitor": {
      "cluster": ["monitor"]
    }
  },
  "metadata": {
    "application": "icinga",
    "environment": {
       "level": 1,
       "trusted": true
    }
  }
}
'

  ## Check API user exists
  CURL_RAW_RESPONSE="$(/usr/share/neteye/elasticsearch/scripts/es_curl.sh -sS -w '{"ErrorCode": %{http_code}}' -XGET https://elasticsearch.neteyelocal:9200/_security/api_key?name=${API_NAME} )"

  result=$(echo $CURL_RAW_RESPONSE | jq 'select(.api_keys!=null).api_keys')
  status=$(echo $CURL_RAW_RESPONSE | jq 'select(.ErrorCode!=null).ErrorCode')

  if [[ $status -ne 200 ]]
  then
    echo $CURL_RAW_RESPONSE | jq 'select(.error!=null).error'
    exit 1
  fi

  if [[ -n $result ]] && [[ $result == "[]" ]]; then
    echo "Create the new api key"
      ## Add API user
      CURL_RAW_RESPONSE="$(/usr/share/neteye/elasticsearch/scripts/es_curl.sh -sS -w '{"ErrorCode": %{http_code}}' -XPOST 'https://elasticsearch.neteyelocal:9200/_security/api_key' -H 'Content-Type: application/json' -d "$JSON_INPUT" )"


      if [[ $status -ne 200 ]]
      then
      echo $CURL_RAW_RESPONSE | jq 'select(.error!=null).error'
      exit 1
      else
      ##{"id":"W3pCo4MByA8i2Wf0oW2D","name":"${API_NAME}","api_key":"F2wZTsIYQbKRxc5BZ9YUWA","encoded":"VzNwQ280TUJ5QThpMldmMG9XMkQ6RjJ3WlRzSVlRYktSeGM1Qlo5WVVXQQ=="}{"ErrorCode": 200}
      echo "API keys with name '${API_NAME}' created successfull!"
      ## Write API on auth_file
      echo $CURL_RAW_RESPONSE | jq 'select(.encoded!=null)' > $FILE
      exit 0
      fi

  else
      echo "API key with name '${API_NAME}' already exist. Nothing to do."
  fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    add_api_user
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icinga2-master"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            add_api_user
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