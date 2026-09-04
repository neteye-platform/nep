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

CACHE_DIR="${JSON_FILE%.json}.d"
TMP_AGENTS=$(mktemp)
TMP_CACHE_DIR=$(mktemp -d "${CACHE_DIR}.tmp.XXXXXX")
CACHE_OLD="${CACHE_DIR}.old"
trap 'rm -f "$TMP_AGENTS"; rm -rf "$TMP_CACHE_DIR"' EXIT

####### MAIN #############
KBN_USER="kibana_monitoring"
KBN_PASSWORD="@@PASSWORD@@"
PER_PAGE=200
TOTAL_HOSTS=0

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
            echo "$KBN_RESPONSE" | jq -c 'select(.items != null) | .items[]' >> "$TMP_AGENTS"

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

# Deduplicate agents that can appear in multiple spaces.
jq -s 'unique_by(.id)' "$TMP_AGENTS" > "$JSON_FILE"

# Materialize one cache file per normalized hostname.
jq -r '
    .[]
    | select((.local_metadata.host.hostname // "") != "")
    | [(.local_metadata.host.hostname | ascii_downcase), (@base64)]
    | @tsv
' "$JSON_FILE" |
while IFS=$'\t' read -r HOST_KEY AGENT_B64; do
    printf '%s' "$AGENT_B64" | base64 -d >> "$TMP_CACHE_DIR/$HOST_KEY"
    printf '\n' >> "$TMP_CACHE_DIR/$HOST_KEY"
done

# Publish the new cache only after it has been completely generated.
rm -rf "$CACHE_OLD"
if [ -d "$CACHE_DIR" ]; then
    if ! mv "$CACHE_DIR" "$CACHE_OLD"; then
        echo "[!] Unable to preserve previous Fleet cache"
        exit 2
    fi
fi

if ! mv "$TMP_CACHE_DIR" "$CACHE_DIR"; then
    echo "[!] Unable to publish new Fleet cache"
    if [ -d "$CACHE_OLD" ]; then
        mv "$CACHE_OLD" "$CACHE_DIR"
    fi
    exit 2
fi

rm -rf "$CACHE_OLD"
echo "Exported $TOTAL_HOSTS host(s) from Kibana Fleet Management.|hosts=$TOTAL_HOSTS;;;0;"
