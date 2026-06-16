#!/usr/bin/env bash
###########################################################
## Retrive all ElasticAgent status from Kibana Fleet API ##
###########################################################

DEFAULT_FILE="/neteye/shared/icinga2/data/lib/icinga2/elastic-agent_status.json"

print_help() {
    echo ""
    echo "This script retrive ElasticAgent status by Kibana Fleet API and write to Json File"
    echo ""
    echo "Usage:"
    echo "-h"
    echo "-f <file_path>    [optional]    ... file path of JSON result of Fleet API (default: $DEFAULT_FILE)"
    echo "-S  Enable SSL"
    exit 0
}

# --- Read options
while getopts "hf:S" opt; do
    case "${opt}" in
    f)
        JSON_FILE=${OPTARG}
        ;;
    h)
        print_help
        ;;
    S)
        ssl_enabled=1
        ;;
    *)
        print_help
        ;;
    esac
done

if [ -z $JSON_FILE ]; then
    JSON_FILE=$DEFAULT_FILE
fi

####### MAIN #############
KBN_USER="kibana_monitoring"
KBN_PASSWORD="@@PASSWORD@@"
PER_PAGE=200
TOTAL_HOSTS=0
ALL_AGENTS="[]"

# Get spaces
if [[ $ssl_enabled -eq 1 ]]; then
    SPACES_RESPONSE=$(/usr/bin/curl -u "${KBN_USER}:${KBN_PASSWORD}" \
        -XGET -H 'kbn-xsrf: true' \
        "https://kibana.neteyelocal:5601/api/spaces/space" \
        -sS)
else
    SPACES_RESPONSE=$(/usr/bin/curl -u "${KBN_USER}:${KBN_PASSWORD}" \
        -XGET -H 'kbn-xsrf: true' \
        "http://kibana.neteyelocal:5601/api/spaces/space" \
        -sS)
fi

SPACE_IDS=$(echo "$SPACES_RESPONSE" | jq -r '.[].id')

for SPACE_ID in $SPACE_IDS; do
    PAGE=1
    PAGES=1

    while true; do
        # Build URL depending on space
        if [[ "$SPACE_ID" == "default" ]]; then
            if [[ $ssl_enabled -eq 1 ]]; then
                URL="https://kibana.neteyelocal:5601/api/fleet/agents?perPage=$PER_PAGE&page=$PAGE"
            else
                URL="http://kibana.neteyelocal:5601/api/fleet/agents?perPage=$PER_PAGE&page=$PAGE"
            fi
        else
            if [[ $ssl_enabled -eq 1 ]]; then
                URL="https://kibana.neteyelocal:5601/s/${SPACE_ID}/api/fleet/agents?perPage=$PER_PAGE&page=$PAGE"
            else
                URL="http://kibana.neteyelocal:5601/s/${SPACE_ID}/api/fleet/agents?perPage=$PER_PAGE&page=$PAGE"
            fi
        fi

        KBN_RESPONSE=$(/usr/bin/curl -u "${KBN_USER}:${KBN_PASSWORD}" \
            -XGET -H 'kbn-xsrf: true' \
            "$URL" \
            -sS -w '{"ErrorCode": %{http_code}}')

        KBN_CURL_RESULT="$(echo "$KBN_RESPONSE" | jq 'select(.ErrorCode !=null).ErrorCode')"

        if [[ "$KBN_CURL_RESULT" != "200" ]]; then
            echo "Error on Kibana curl for space: $SPACE_ID page: $PAGE"
            echo "$KBN_RESPONSE"
            exit 2
        else
            AGENTS=$(echo "$KBN_RESPONSE" | jq '.items')
            ALL_AGENTS=$(echo "$ALL_AGENTS $AGENTS" | jq -s 'add')

            if [[ $PAGE -eq 1 ]]; then
                # --- FIX: compute this space's own total/pages, and SUM into the global counter
                SPACE_TOTAL=$(echo "$KBN_RESPONSE" | jq -r '.total' | grep -oE '^[0-9]+')
                PAGES=$(( (SPACE_TOTAL + PER_PAGE - 1) / PER_PAGE ))
                TOTAL_HOSTS=$(( TOTAL_HOSTS + SPACE_TOTAL ))
            fi

            if [[ $PAGE -ge $PAGES ]]; then
                break
            fi

            PAGE=$((PAGE + 1))
        fi
    done
done

# FIX: guard against an agent appearing under multiple spaces
# (e.g. a policy whose space_ids lists more than one space)
ALL_AGENTS=$(echo "$ALL_AGENTS" | jq 'unique_by(.id)')
# Write the aggregated result to the file
echo "$ALL_AGENTS" | jq '.' >$JSON_FILE
#echo "$ALL_AGENTS" | jq
echo "Exported $TOTAL_HOSTS host(s) from Kibana Fleet Management.|hosts=$TOTAL_HOSTS;;;0;"
