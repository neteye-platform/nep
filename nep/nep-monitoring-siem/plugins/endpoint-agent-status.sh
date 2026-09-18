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

CACHE_DIR="${JSON_FILE%.json}.d"
TMP_JSON=$(mktemp "${JSON_FILE}.tmp.XXXXXX")
TMP_CACHE_MAP=$(mktemp)
TMP_CACHE_DIR=$(mktemp -d "${CACHE_DIR}.tmp.XXXXXX")
CACHE_OLD="${CACHE_DIR}.old"
trap 'rm -f "$TMP_JSON" "$TMP_CACHE_MAP"; rm -rf "$TMP_CACHE_DIR"' EXIT

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

# Build the aggregated result without truncating the currently published file.
if ! printf '%s\n' "$AGENTS" | jq '.' > "$TMP_JSON"; then
    echo "[!] Failed to build aggregated Endpoint JSON; keeping previous data"
    exit 2
fi

# Build the hostname/cache mapping before publishing anything.
if ! jq -r '
    select((.host.hostname // "") != "")
    | [(.host.hostname | ascii_downcase), (@base64)]
    | @tsv
' "$TMP_JSON" > "$TMP_CACHE_MAP"; then
    echo "[!] Failed to build Endpoint cache mapping; keeping previous data"
    exit 2
fi

while IFS=$'\t' read -r HOST_KEY ENDPOINT_B64; do
    if [[ ! "$HOST_KEY" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
        continue
    fi
    printf '%s' "$ENDPOINT_B64" | base64 -d >> "$TMP_CACHE_DIR/$HOST_KEY"
    printf '\n' >> "$TMP_CACHE_DIR/$HOST_KEY"
done < "$TMP_CACHE_MAP"

# Preserve the permissions expected by monitoring consumers.
if ! chmod 0644 "$TMP_JSON"; then
    echo "[!] Unable to set aggregated JSON permissions"
    exit 2
fi

if ! chmod 0755 "$TMP_CACHE_DIR"; then
    echo "[!] Unable to set cache directory permissions"
    exit 2
fi

if ! find "$TMP_CACHE_DIR" -type f -exec chmod 0644 {} +; then
    echo "[!] Unable to set cache file permissions"
    exit 2
fi

if ! mv "$TMP_JSON" "$JSON_FILE"; then
    echo "[!] Unable to publish aggregated Endpoint JSON"
    exit 2
fi

# Publish the new cache only after it has been completely generated.
rm -rf "$CACHE_OLD"
if [ -d "$CACHE_DIR" ]; then
    if ! mv "$CACHE_DIR" "$CACHE_OLD"; then
        echo "[!] Unable to preserve previous Endpoint cache"
        exit 2
    fi
fi

if ! mv "$TMP_CACHE_DIR" "$CACHE_DIR"; then
    echo "[!] Unable to publish new Endpoint cache"
    if [ -d "$CACHE_OLD" ]; then
        mv "$CACHE_OLD" "$CACHE_DIR"
    fi
    exit 2
fi

rm -rf "$CACHE_OLD"

echo "Exported $TOTAL_HOSTS Elastic Agent Endpoint(s) from Elasticsearch.|hosts=$TOTAL_HOSTS;;;0;"

