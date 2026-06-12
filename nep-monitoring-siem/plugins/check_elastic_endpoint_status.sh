#!/usr/bin/env bash

DEFAULT_FILE="/neteye/shared/icinga2/data/lib/icinga2/elastic-endpoint_status.json"

print_help() {
    echo ""
    echo "This script check Elastic Endpoint status from JSON file retrived by Elasticsearch"
    echo ""
    echo "Usage:"
    echo "-h"
    echo "-H <hostname>     [required]    ... hostname FQDN"
    echo "-f <file_path>    [optional]    ... file path of JSON result (default: $DEFAULT_FILE)"
    exit 0
}

# --- Read options
while getopts "hH:f:" opt; do
    case "${opt}" in
        H)
            HOST_FQDN=${OPTARG}
            ;;
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

if [ -z $HOST_FQDN ]; then
    echo ""
    echo "Hostname is required!"
    print_help
    exit 1
fi

if [ -z $JSON_FILE ]; then
    JSON_FILE=$DEFAULT_FILE
fi

# Extract value for current host
STATUS_JSON=$(jq -r 'select(.host.hostname | ascii_downcase == "'$HOST_FQDN'")' $JSON_FILE)

# Check if host exist
if [ -z "$STATUS_JSON" ]; then
    echo "CHECK UNKNOWN - Endpoint not found on Endpoint Management."
    exit 3
else
    # check duplicated
    ITEMS=$(echo $STATUS_JSON | jq '.agent.id' | wc -l)
    if [ "$ITEMS" != "1" ]; then
        echo "CHECK CRITICAL - Duplicated host on Endpoint Management!\nCheck and remove duplicates manually..."
        exit 2
    fi
fi

ENDPOINT_POLICY_STATUS=$(echo $STATUS_JSON | jq -r ".Endpoint.policy.applied.status")
ENDPOINT_POLICY_VERSION=$(echo $STATUS_JSON | jq -r ".Endpoint.policy.applied.version")
ENDPOINT_POLICY_NAME=$(echo $STATUS_JSON | jq -r ".Endpoint.policy.applied.name")
ENDPOINT_CAPABILITIES=$(echo $STATUS_JSON | jq -r ".Endpoint.capabilities")
ENDPOINT_STATE=$(echo $STATUS_JSON | jq -r ".Endpoint.state")

message="<br>Policy Integration Version: $ENDPOINT_POLICY_VERSION<br>Policy Integration Name: $ENDPOINT_POLICY_NAME<br>"
message+="Capabilities: $ENDPOINT_CAPABILITIES<br>State: $ENDPOINT_STATE"

if [ "$ENDPOINT_POLICY_STATUS" = "success" ];then
    echo "CHECK OK - Endpoint Policy status is $ENDPOINT_POLICY_STATUS. $message"
elif [ "$ENDPOINT_POLICY_STATUS" = "warning" ] || [ "$ENDPOINT_POLICY_STATUS" = "partially applied" ]; then
    echo "CHECK WARNING - Endpoint Policy status is $ENDPOINT_POLICY_STATUS, policy is pending application or the policy was not applied in its entirety. $message"
    exit 1
elif [ "$ENDPOINT_POLICY_STATUS" = "failure" ]; then
    echo "CHECK CRITICAL - Endpoint Policy status is $ENDPOINT_POLICY_STATUS, the policy did not apply correctly, and endpoint is not protected. $message"
    exit 2
fi