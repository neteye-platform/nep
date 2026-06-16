#!/usr/bin/env bash
############################################################
## Retrive all Elastic Endpoint status from Elasticsearch ##
############################################################

DEFAULT_FILE="/neteye/shared/icinga2/data/lib/icinga2/elastic-endpoint_status.json"

print_help() {
    echo ""
    echo "This script retrive Elastic Endpoint status from Elasticsearch and writes to Json File"
    echo ""
    echo "Usage:"
    echo "-h"
    echo "-f <file_path>    [optional]    ... file path of JSON result (default: $DEFAULT_FILE)"
    exit 0
}

# --- Read options
while getopts "hf:" opt; do
    case "${opt}" in
        f)
            JSON_FILE=${OPTARG}
            ;;
        h)
            print_help
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
ES_CURL_DIR="/usr/share/neteye/elasticsearch/scripts/"
TOTAL_HOSTS=0
ALL_AGENTS="[]"

CURL_RAW_RESPONSE="$(${ES_CURL_DIR}/es_neteye_curl.sh -sS -w '{"ErrorCode": %{http_code}}' -H 'Content-Type: application/json' -X GET https://elasticsearch.neteyelocal:9200/.ds-metrics-endpoint.metadata-*/_search -d '
{
    "aggs": {
        "group_by_hostname": {
        "terms": { "field": "host.hostname", "size": 65000 },
        "aggs": {
            "latest_event_for_hostname": {
            "top_hits": {
                "size": 1,
                "sort": [{ "@timestamp": { "order": "desc" } }],
                "_source": [ "@timestamp", "agent.id", "host.hostname", "Endpoint.policy.applied.status", "Endpoint.status", "Endpoint.state", "Endpoint.policy.applied" ]
            }
            }
        }
        }
    },
    "size": 0
    }
')"
# Setting "size" to 65000 to avoid limit in result (see https://www.elastic.co/guide/en/elasticsearch/reference/8.17/search-aggregations-bucket.html)

ES_CURL_HTTP_CODE="$(echo "$CURL_RAW_RESPONSE" | jq 'select(.ErrorCode !=null).ErrorCode')"

if [[ "$ES_CURL_HTTP_CODE" != "200" ]];then
    echo "[!] Error on Elasticsearch curl"
    echo $CURL_RAW_RESPONSE
    exit 2
else
    # Extract agents from the response
    AGENTS=$(echo "$CURL_RAW_RESPONSE" | jq -c 'select(.ErrorCode == null) | .aggregations.group_by_hostname.buckets[].latest_event_for_hostname.hits.hits[0]._source')

    # Get total number of agents
    TOTAL_HOSTS=$(echo "$AGENTS" | wc -l)
fi

# Write the aggregated result to the file
echo "$AGENTS" | jq '.' > $JSON_FILE
echo "Exported $TOTAL_HOSTS Elastic Agent Endpoint(s) from Elasticsearch.|hosts=$TOTAL_HOSTS;;;0;"

