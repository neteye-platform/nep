#!/usr/bin/env bash

DEFAULT_FILE="/neteye/shared/icinga2/data/lib/icinga2/elastic-agent_status.json"
POLICIES_FILE="/neteye/shared/icinga2/data/lib/icinga2/elastic-agent_policies.json"

print_help() {
    echo ""
    echo "This script check Elastic Agent Status from JSON file retrived by Fleet API status"
    echo ""
    echo "Usage:"
    echo "-h"
    echo "-H <hostname>     [required]    ... hostname FQDN"
    echo "-f <file_path>    [optional]    ... file path of JSON result of Fleet API (default: $DEFAULT_FILE)"
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

if [ -z $JSON_POLICY ]; then
    JSON_POLICY=$POLICIES_FILE
fi


# Extract value for current host
STATUS_JSON=$(jq ".[] | select(.local_metadata.host.hostname | ascii_downcase  == \"$HOST_FQDN\")" $JSON_FILE)

# Check if host exist
if [ -z "$STATUS_JSON" ]; then
    echo "CHECK UNKNOWN - Agent not found on Fleet Management."
    exit 3
else
    # check duplicated
    ITEMS=$(echo $STATUS_JSON | jq '.agent.id' | wc -l)
    if [ "$ITEMS" != "1" ]; then
        echo "CHECK CRITICAL - Duplicated host on Fleet Management!\nCheck and remove duplicates manually..."
        exit 2
    fi
fi

AGENT_STATUS=$(echo $STATUS_JSON | jq -r ".status")
AGENT_VERSION=$(echo $STATUS_JSON | jq -r ".agent.version")
AGENT_ID=$(echo $STATUS_JSON | jq -r ".agent.id")
AGENT_POLICY_ID=$(echo $STATUS_JSON | jq -r ".policy_id")
AGENT_POLICY_REVISION=$(echo $STATUS_JSON | jq -r ".policy_revision")

message="<br>Agent Version: $AGENT_VERSION<br>Agent ID: $AGENT_ID<br>Agent Policy: $AGENT_POLICY_ID"

## Retrive Agent Policy Json
POLICY_JSON=$(jq ".[] | select(.id == \"$AGENT_POLICY_ID\")" $JSON_POLICY)
POLICY_REVISION=$(echo $POLICY_JSON | jq -r ".revision")


if [ "$AGENT_STATUS" = "online" ] && [ "$AGENT_POLICY_REVISION" = "$POLICY_REVISION" ];then
    echo "CHECK OK - Agent is $AGENT_STATUS. $message"
elif [ "$AGENT_STATUS" = "unhealthy" ] || [ "$AGENT_STATUS" = "updating" ] || [ "$AGENT_STATUS" = "degraded" ]; then
    # ERROR_MESSAGE=$(echo $STATUS_JSON | jq -r ".last_checkin_message")
    ERROR_MESSAGE=$(echo $STATUS_JSON | jq -r ".components[].units[] | select(.status==\"FAILED\" or .status==\"DEGRADED\") | .message")
    echo "CHECK WARNING - Agent is $AGENT_STATUS! $message <br> $ERROR_MESSAGE"
    exit 1
elif [ "$AGENT_STATUS" = "error" ] || [ "$AGENT_STATUS" = "offline" ] || [ "$AGENT_STATUS" = "orphaned" ]; then
    echo "CHECK CRITICAL - Agent status is $AGENT_STATUS, check Fleet Dashboard. $message"
    exit 2
elif (( AGENT_POLICY_REVISION < POLICY_REVISION ));then
    echo "CHECK WARNING - Agent policy is v.$AGENT_POLICY_REVISION that is different from Fleet Policy v.$POLICY_REVISION! $message"
    exit 1
fi
