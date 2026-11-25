#!/usr/bin/env bash

DATA_DIR="/neteye/shared/icinga2/data/lib/icinga2"
STATUS_PREFIX="elastic-agent_status"
POLICIES_PREFIX="elastic-agent_policies"

# Optional hostname prefixes used by containerized agents (space separated),
# e.g. "elastic-agent-container": if the exact hostname is not found, the
# check also tries "<prefix>.<hostname>".
# Disabled by default: container agents are monitored by a dedicated Director
# service that passes -H elastic-agent-container.$host.name$ explicitly, and a
# fallback would hide a missing host agent behind the container agent.
AGENT_HOST_PREFIXES=""

print_help() {
    echo ""
    echo "This script checks Elastic Agent status from the JSON file retrieved from the Fleet API."
    echo ""
    echo "Usage:"
    echo "-h"
    echo "-H <hostname>     [required]    ... hostname FQDN (Icinga host)"
    echo "-a <agent_host>   [optional]    ... exact agent hostname as reported by Fleet"
    echo "                                    (disables the container prefix fallback)"
    echo "-T <tenant>       [optional]    ... NetEye tenant (reads ${STATUS_PREFIX}_<tenant>.json)"
    echo "-f <file_path>    [optional]    ... override status JSON file"
    echo "-p <file_path>    [optional]    ... override policies JSON file"
    echo "-s                [optional]    ... strict: CRITICAL on any duplicate, even stale/offline ones"
}

# Read options
while getopts "hH:a:T:f:p:s" opt; do
    case "${opt}" in
        H) HOST_FQDN=${OPTARG} ;;
        a) AGENT_HOST=${OPTARG} ;;
        T) TENANT=${OPTARG} ;;
        f) JSON_FILE=${OPTARG} ;;
        p) JSON_POLICY=${OPTARG} ;;
        s) STRICT=1 ;;
        h) print_help; exit 0 ;;
        *) print_help; exit 3 ;;
    esac
done

if [ -z "$HOST_FQDN" ]; then
    echo "Hostname is required!"
    print_help
    exit 3
fi

valid_host() { [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; }

HOST_KEY=$(echo "$HOST_FQDN" | tr '[:upper:]' '[:lower:]')
if ! valid_host "$HOST_KEY"; then
    echo "CHECK UNKNOWN - Invalid hostname for status cache lookup."
    exit 3
fi

# Tenant handling
if [ -n "$TENANT" ]; then
    TENANT_KEY=$(echo "$TENANT" | tr '[:upper:]' '[:lower:]')
    if [[ ! "$TENANT_KEY" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
        echo "CHECK UNKNOWN - Invalid tenant name: $TENANT"
        exit 3
    fi
    SUFFIX="_${TENANT_KEY}"
    TENANT_MSG=" (tenant: $TENANT_KEY)"
else
    SUFFIX=""
    TENANT_MSG=""
fi

: "${JSON_FILE:=$DATA_DIR/${STATUS_PREFIX}${SUFFIX}.json}"
if [ -z "$JSON_POLICY" ]; then
    JSON_POLICY="$DATA_DIR/${POLICIES_PREFIX}${SUFFIX}.json"
    if [ -n "$SUFFIX" ] && [ ! -r "$JSON_POLICY" ]; then
        JSON_POLICY="$DATA_DIR/${POLICIES_PREFIX}.json"
    fi
fi

CACHE_DIR="${JSON_FILE%.json}.d"

if [ ! -d "$CACHE_DIR" ] && [ ! -r "$JSON_FILE" ]; then
    echo "CHECK UNKNOWN - Fleet status file not readable${TENANT_MSG}: $JSON_FILE"
    exit 3
fi

# lookup_agent <agent_hostname>: prints the matching records (may be empty)
lookup_agent() {
    if [ -r "$CACHE_DIR/$1" ]; then
        cat "$CACHE_DIR/$1"
    elif [ ! -d "$CACHE_DIR" ]; then
        jq --arg host "$1" \
            '.[] | select((.local_metadata.host.hostname // "" | ascii_downcase) == $host)' \
            "$JSON_FILE"
    fi
}

# --- Candidate agent hostnames
if [ -n "$AGENT_HOST" ]; then
    AGENT_KEY=$(echo "$AGENT_HOST" | tr '[:upper:]' '[:lower:]')
    if ! valid_host "$AGENT_KEY"; then
        echo "CHECK UNKNOWN - Invalid agent hostname: $AGENT_HOST"
        exit 3
    fi
    CANDIDATES=("$AGENT_KEY")
else
    CANDIDATES=("$HOST_KEY")
    for P in $AGENT_HOST_PREFIXES; do
        CANDIDATES+=("${P}.${HOST_KEY}")
    done
fi

RAW_JSON=""
MATCHED=""
for C in "${CANDIDATES[@]}"; do
    RAW_JSON=$(lookup_agent "$C") || { echo "CHECK UNKNOWN - Unable to parse $JSON_FILE"; exit 3; }
    if [ -n "$RAW_JSON" ]; then
        MATCHED="$C"
        break
    fi
done

# Normalize, deduplicate by agent.id, newest check-in first
AGENTS_JSON=$(printf '%s\n' "$RAW_JSON" | jq -s '
    [ .[] | if type == "array" then .[] else . end ]
    | unique_by(.agent.id)
    | sort_by(.last_checkin // "") | reverse') \
    || { echo "CHECK UNKNOWN - Invalid agent JSON for $HOST_KEY${TENANT_MSG}."; exit 3; }

ITEMS=$(printf '%s\n' "$AGENTS_JSON" | jq 'length')

if [ "$ITEMS" -eq 0 ]; then
    echo "CHECK UNKNOWN - Agent not found on Fleet Management${TENANT_MSG}. Searched: ${CANDIDATES[*]}"
    exit 3
fi

STALE_MSG=""
if [ "$ITEMS" -gt 1 ]; then
    ACTIVE_COUNT=$(printf '%s\n' "$AGENTS_JSON" | jq \
        '[.[] | select(.status | IN("offline","inactive","unenrolled") | not)] | length')
    LIST=$(printf '%s\n' "$AGENTS_JSON" | jq -r \
        '[.[] | "\(.agent.id) [\(.status), last check-in \(.last_checkin // "n/a")]"] | join("<br>")')

    if [ "$STRICT" = "1" ] || [ "$ACTIVE_COUNT" -gt 1 ]; then
        echo "CHECK CRITICAL - Duplicated host $MATCHED on Fleet Management${TENANT_MSG}! Check and remove duplicates manually...<br>$LIST"
        exit 2
    fi

    # Keep the active agent (or the newest one if all are offline); ignore stale ones
    STATUS_JSON=$(printf '%s\n' "$AGENTS_JSON" | jq '
        (map(select(.status | IN("offline","inactive","unenrolled") | not))) as $a
        | if ($a | length) > 0 then $a[0] else .[0] end')
    KEEP_ID=$(printf '%s\n' "$STATUS_JSON" | jq -r '.agent.id')
    STALE_IDS=$(printf '%s\n' "$AGENTS_JSON" | jq -r --arg keep "$KEEP_ID" \
        '[.[] | select(.agent.id != $keep) | .agent.id] | join(", ")')
    STALE_MSG="<br>Ignored $((ITEMS - 1)) stale agent(s) with same hostname: $STALE_IDS"
else
    STATUS_JSON=$(printf '%s\n' "$AGENTS_JSON" | jq '.[0]')
fi

AGENT_STATUS=$(printf '%s\n' "$STATUS_JSON" | jq -r '.status')
AGENT_VERSION=$(printf '%s\n' "$STATUS_JSON" | jq -r '.agent.version')
AGENT_ID=$(printf '%s\n' "$STATUS_JSON" | jq -r '.agent.id')
AGENT_POLICY_ID=$(printf '%s\n' "$STATUS_JSON" | jq -r '.policy_id')
AGENT_POLICY_REVISION=$(printf '%s\n' "$STATUS_JSON" | jq -r '.policy_revision')
AGENT_POLICY_BASE_ID=$(printf '%s\n' "$STATUS_JSON" | jq -r '.policy_base_id // (.policy_id // "" | split("#")[0])')

message="<br>Agent Version: $AGENT_VERSION<br>Agent ID: $AGENT_ID<br>Agent Policy: $AGENT_POLICY_ID"
[ "$MATCHED" != "$HOST_KEY" ] && message="$message<br>Agent Hostname: $MATCHED"
[ -n "$TENANT_KEY" ] && message="$message<br>Tenant: $TENANT_KEY"
message="$message$STALE_MSG"

# Evaluate agent status
case "$AGENT_STATUS" in
    error|offline|orphaned)
        echo "CHECK CRITICAL - Agent status is $AGENT_STATUS, check Fleet Dashboard. $message"
        exit 2
        ;;
    unhealthy|updating|degraded)
        ERROR_MESSAGE=$(printf '%s\n' "$STATUS_JSON" | jq -r \
            '.components[]?.units[]? | select(.status=="FAILED" or .status=="DEGRADED") | .message')
        echo "CHECK WARNING - Agent is $AGENT_STATUS! $message <br> $ERROR_MESSAGE"
        exit 1
        ;;
    online)
        ;;
    *)
        echo "CHECK UNKNOWN - Unexpected agent status: $AGENT_STATUS. $message"
        exit 3
        ;;
esac

# Agent is online: compare with Fleet policy revision
if [ ! -r "$JSON_POLICY" ]; then
    echo "CHECK UNKNOWN - Fleet policy file is not readable: $JSON_POLICY. $message"
    exit 3
fi

if [ -z "$AGENT_POLICY_ID" ] || [ "$AGENT_POLICY_ID" = "null" ]; then
    echo "CHECK UNKNOWN - Agent policy ID is missing. $message"
    exit 3
fi

if ! [[ "$AGENT_POLICY_REVISION" =~ ^[0-9]+$ ]]; then
    echo "CHECK UNKNOWN - Invalid agent policy revision: $AGENT_POLICY_REVISION. $message"
    exit 3
fi

POLICY_JSON=$(jq --arg policy_id "$AGENT_POLICY_ID" --arg base_id "$AGENT_POLICY_BASE_ID" \
    'first(.[] | select(.id == $policy_id)) // first(.[] | select(.id == $base_id)) // empty' \
    "$JSON_POLICY")

if [ -z "$POLICY_JSON" ]; then
    echo "CHECK UNKNOWN - Fleet policy $AGENT_POLICY_ID not found${TENANT_MSG}. $message"
    exit 3
fi

POLICY_REVISION=$(printf '%s\n' "$POLICY_JSON" | jq -r '.revision')

if ! [[ "$POLICY_REVISION" =~ ^[0-9]+$ ]]; then
    echo "CHECK UNKNOWN - Invalid Fleet policy revision: $POLICY_REVISION. $message"
    exit 3
fi

if (( AGENT_POLICY_REVISION == POLICY_REVISION )); then
    echo "CHECK OK - Agent is online. $message"
    exit 0
else
    echo "CHECK WARNING - Agent policy is v.$AGENT_POLICY_REVISION that is different from Fleet Policy v.$POLICY_REVISION! $message"
    exit 1
fi
