#!/bin/bash

#
# Version: X
# Developed by XXX
#

PROGNAME=$(basename $0)
VERSION="1"

# Logstash config options
LS_HOST="localhost"
LS_PORT="9600"
LS_PROTOCOL="http"
LS_COMMAND_PATH="/usr/bin/curl"

LS_TEMP_PATH="/tmp"

# Icinga compatible return values
CRITICAL_RET=2
WARNING_RET=1
UNKNOWN_RET=3
OK_RET=0

# defaults
DO_TOTAL_EPS=true
CHECK_PIPELINE=false
PIPELINE=""

#### Functions
check_threshold_existence() {
    local WARNING_THRESHOLD=$1
    local CRITICAL_THRESHOLD=$2
    # Check if warning threshold smaller than critical one
    if [[ "$CRITICAL_THRESHOLD" -lt "${WARNING_THRESHOLD}" ]] && [[ "$CRITICAL_THRESHOLD" -ne 0 ]]; then
        echo "CHECK UNKNOWN - Critical Threshold '${CRITICAL_THRESHOLD}' should be bigger than or equal to warning threshold '${WARNING_THRESHOLD}'"
        exit "${UNKNOWN}"
    fi
}

manage_nagios_range() {
    if [[ $WARNING_THRESHOLD == *":"* ]]; then
        MIN_WARN=$(echo ${WARNING_THRESHOLD} | cut -d ":" -f 1)
        MAX_WARN=$(echo ${WARNING_THRESHOLD} | cut -d ":" -f 2)
    else
        MIN_WARN=0
        MAX_WARN=$WARNING_THRESHOLD
    fi
    if [[ $CRITICAL_THRESHOLD == *":"* ]]; then
        MIN_CRIT=$(echo ${CRITICAL_THRESHOLD} | cut -d ":" -f 1)
        MAX_CRIT=$(echo ${CRITICAL_THRESHOLD} | cut -d ":" -f 2)
    else
        MIN_CRIT=0
        MAX_CRIT=$CRITICAL_THRESHOLD
    fi

    if [[ -z $MIN_CRIT ]]; then
        MIN_CRIT=0
    fi
    if [[ -z $MAX_CRIT ]]; then
        MAX_CRIT=0
    fi
    if [[ -z $MAX_WARN ]]; then
        MAX_WARN=0
    fi
    if [[ -z $MIN_WARN ]]; then
        MIN_WARN=0
    fi
}

function getPipelineDeatils() {
    k=$PIPELINE

    PIPELINES_JSON_RES=$("$LS_COMMAND_PATH" --fail -XGET "$URL/$LS_PATH_PIPELINES/$PIPELINE" --silent 2>/dev/null)
    LAST_RELOAD_ERROR=$(echo $PIPELINES_JSON_RES | jq -r '.pipelines.'$k'.reloads.last_error.message')

    if [[ -z "${PIPELINES_JSON_RES// /}" ]] || [[ -z $LAST_RELOAD_ERROR ]]; then
        echo "CHECK UNKNOWN - an error occured. Check that pipeline name is correct"
        echo "$LAST_RELOAD_ERROR"
        exit "${UNKNOWN_RET}"
    else
        ITEM=$(echo $PIPELINES_JSON_RES | jq ' {host: .host , '$k': {in: .pipelines.'$k'.events.in, out: .pipelines.'$k'.events.out , duration_in_millis: .pipelines.'$k'.events.duration_in_millis}}')

        if [[ $(echo "$ITEM" | jq '.'$k'.in ') != null ]]; then

            P_HOST=$(echo "$ITEM" | jq --raw-output '.host')
            P_IN_EVENTS=$(echo "$ITEM" | jq '.'$k'.in | tonumber')
            P_OUT_EVENTS=$(echo "$ITEM" | jq '.'$k'.out | tonumber')
            P_DURATION_MS=$(echo "$ITEM" | jq '.'$k'.duration_in_millis | tonumber')
            P_DURATION_S=$(echo "scale=4; $P_DURATION_MS/1000" | bc | awk '{printf "%.4f", $0}')

            OUT_EVENT_PER_SECOND=0
            IN_EVENT_PER_SECOND=0

            #Compose ref. pipeline file name
            FILE_NAME=$(echo $LS_TEMP_PATH"/"$P_HOST"_"$PIPELINE".json")

            #Check ref. pipeline file exists
            if [ -f "$FILE_NAME" ]; then
                PREVIOUS_CHECK=$(cat "$FILE_NAME")

                PC_IN_EVENTS=$(echo "$PREVIOUS_CHECK" | jq '.'$k'.in | tonumber')
                PC_OUT_EVENTS=$(echo "$PREVIOUS_CHECK" | jq '.'$k'.out | tonumber')
                PC_DURATION_MS=$(echo "$PREVIOUS_CHECK" | jq '.'$k'.duration_in_millis | tonumber')

                if [[ $P_DURATION_MS -gt 0 && $P_DURATION_MS -gt $PC_DURATION_MS ]]; then

                    TIME_INTEVAL_MS=$(expr $P_DURATION_MS - $PC_DURATION_MS)
                    TIME_INTEVAL_SECS=$(echo "scale=4; $TIME_INTEVAL_MS / 1000" | bc | awk '{printf "%.4f", $0}')

                    if [[ $TIME_INTEVAL_SECS == "0.0000" ]]; then
                        echo "UNKNOWN - Check run too quicly."
                        exit $UNKNOWN_RET
                    fi
                    #########################
                    #  OUT Events Pipeline
                    #########################
                    if [[ $P_OUT_EVENTS -gt 0 && $P_OUT_EVENTS -gt $PC_OUT_EVENTS ]]; then
                        DIFF_OUT_EVENTS=$(expr $P_OUT_EVENTS - $PC_OUT_EVENTS)
                        OUT_EVENT_PER_SECOND=$(echo "scale=1; $DIFF_OUT_EVENTS / $TIME_INTEVAL_SECS" | bc | awk '{printf "%.1f", $0}')
                    else
                        #Logstash restart or other trouble
                        OUT_EVENT_PER_SECOND=0
                    fi

                    #########################
                    #  IN Events Pipeline
                    #########################
                    if [[ $P_IN_EVENTS -gt 0 && $P_IN_EVENTS -gt $PC_IN_EVENTS ]]; then
                        DIFF_IN_EVENTS=$(expr $P_IN_EVENTS - $PC_IN_EVENTS)
                        IN_EVENT_PER_SECOND=$(echo "scale=1; $DIFF_IN_EVENTS / $TIME_INTEVAL_SECS" | bc | awk '{printf "%.1f", $0}')
                    else
                        #Logstash restart or other trouble
                        IN_EVENT_PER_SECOND=0
                    fi

                else
                    #Logstash restart or other trouble
                    IN_EVENT_PER_SECOND=0
                    OUT_EVENT_PER_SECOND=0
                fi

            else
                # A file with previous statistics does't exist! (First run or someone has delete it!)
                IN_EVENT_PER_SECOND=0
                OUT_EVENT_PER_SECOND=0
            fi

            ######################################################
            # Create or update file with current statistics
            ######################################################
            $(echo "$ITEM" >"$FILE_NAME")

            ########################
            # Evaluate results
            ########################
            if (( ${OUT_EVENT_PER_SECOND/\.*} > $MAX_CRIT )) && (( $MAX_CRIT != 0 )); then
                echo "CHECK CRITICAL - Events sent from pipeline '$k' are above the threshold of ${MAX_CRIT}EPS"
                echo "HOST: $P_HOST<br>"
                echo "IN events: $P_IN_EVENTS<br>"
                echo "OUT events: $P_OUT_EVENTS<br>"
                echo "Duration: ${P_DURATION_S}s.<br>"
                echo "EPS out: $OUT_EVENT_PER_SECOND<br>"
                echo "EPS in: $IN_EVENT_PER_SECOND<br>"
                echo " | 'outEps'=$OUT_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0; 'inEps'=$IN_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;"
                exit ${CRITICAL_RET}
            elif (( ${OUT_EVENT_PER_SECOND/\.*} < $MIN_CRIT )) && (( $MIN_CRIT != 0 )); then
                echo "CHECK CRITICAL - Events sent from pipeline '$k' are below the threshold of ${MIN_CRIT}EPS"
                echo "HOST: $P_HOST<br>"
                echo "IN events: $P_IN_EVENTS<br>"
                echo "OUT events: $P_OUT_EVENTS<br>"
                echo "Duration: ${P_DURATION_S}s.<br>"
                echo "EPS out: $OUT_EVENT_PER_SECOND<br>"
                echo "EPS in: $IN_EVENT_PER_SECOND<br>"
                echo " | 'outEps'=$OUT_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0; 'inEps'=$IN_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;"
                exit ${CRITICAL_RET}
            elif (( ${OUT_EVENT_PER_SECOND/\.*} > $MAX_WARN )) && (( $MAX_WARN != 0 )); then
                echo "CHECK WARNING - Events sent from pipeline '$k' are above the threshold of ${MAX_WARN}EPS"
                echo "HOST: $P_HOST<br>"
                echo "IN events: $P_IN_EVENTS<br>"
                echo "OUT events: $P_OUT_EVENTS<br>"
                echo "Duration: ${P_DURATION_S}s.<br>"
                echo "EPS out: $OUT_EVENT_PER_SECOND<br>"
                echo "EPS in: $IN_EVENT_PER_SECOND<br>"
                echo " | 'outEps'=$OUT_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0; 'inEps'=$IN_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;"
                exit ${WARNING_RET}
            elif (( ${OUT_EVENT_PER_SECOND/\.*} < $MIN_WARN )) && (( $MIN_WARN != 0 )); then
                echo "CHECK WARNING - Events sent from pipeline '$k' are below the threshold of ${MIN_WARN}EPS"
                echo "HOST: $P_HOST<br>"
                echo "IN events: $P_IN_EVENTS<br>"
                echo "OUT events: $P_OUT_EVENTS<br>"
                echo "Duration: ${P_DURATION_S}s.<br>"
                echo "EPS out: $OUT_EVENT_PER_SECOND<br>"
                echo "EPS in: $IN_EVENT_PER_SECOND<br>"
                echo " | 'outEps'=$OUT_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0; 'inEps'=$IN_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;"
                exit ${WARNING_RET}
            else
                echo "CHECK OK - ${P_OUT_EVENTS} events are sent from pipeline '$k' in ${P_DURATION_S}s"
                echo "HOST: $P_HOST<br>"
                echo "IN events: $P_IN_EVENTS<br>"
                echo "OUT events: $P_OUT_EVENTS<br>"
                echo "Duration: ${P_DURATION_S}s.<br>"
                echo "EPS out: $OUT_EVENT_PER_SECOND<br>"
                echo "EPS in: $IN_EVENT_PER_SECOND<br>"
                echo " | 'outEps'=$OUT_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0; 'inEps'=$IN_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;"
                exit ${OK_RET}
            fi
        fi

    fi

}

function getGlobalDeatils() {
    EVENTS_JSON_RES=$("$LS_COMMAND_PATH" --fail -XGET "$URL/$LS_PATH_EVENTS_STATS" --silent 2>/dev/null)

    if [[ -z "${EVENTS_JSON_RES// /}" ]]; then
        echo "CHECK UNKNOWN - an error occured. Check that logstash is reachable"
        exit "${UNKNOWN_RET}"
    else
        PARSED_RESP=$(echo "$EVENTS_JSON_RES" | jq '. | {host: .host , workers: .pipeline.workers , events: {in: .events.in, out: .events.out , duration_in_millis: .events.duration_in_millis }}')
        IN_EVENTS=$(echo "$PARSED_RESP" | jq '.events.in | tonumber')
        OUT_EVENTS=$(echo "$PARSED_RESP" | jq '.events.out | tonumber')
        HOST=$(echo "$PARSED_RESP" | jq --raw-output '.host')
        DURATION_MS=$(echo "$PARSED_RESP" | jq '.events.duration_in_millis | tonumber')
        WORKERS=$(echo "$PARSED_RESP" | jq '.workers | tonumber')

        DURATION_S=$(echo "scale=1; $DURATION_MS/1000" | bc | awk '{printf "%.1f", $0}')

        # Duration based on num of worker (just for human impact)
        DURATION_W=$(echo "scale=1; $DURATION_MS/$WORKERS" | bc | awk '{printf "%.1f", $0}')
        DURATION_W_S=$(echo "scale=1; $DURATION_W/1000" | bc | awk '{printf "%.1f", $0}')
        DURATION_W_M=$(echo "scale=1; $DURATION_W_S/60" | bc | awk '{printf "%.1f", $0}')
        DURATION_W_H=$(echo "scale=1; $DURATION_W_M/60" | bc | awk '{printf "%.1f", $0}')

        OUT_EVENT_PER_SECOND=0
        IN_EVENT_PER_SECOND=0

        #Compose ref. pipeline file name
        FILE_NAME=$LS_TEMP_PATH"/"$HOST"_globalStats.json"

        #Check ref. pipeline file exists
        if [ -f "$FILE_NAME" ]; then
            PREVIOUS_CHECK=$(cat "$FILE_NAME")

            PC_IN_EVENTS=$(echo "$PREVIOUS_CHECK" | jq '.events.in | tonumber')
            PC_OUT_EVENTS=$(echo "$PREVIOUS_CHECK" | jq '.events.out | tonumber')
            PC_DURATION_MS=$(echo "$PREVIOUS_CHECK" | jq '.events.duration_in_millis | tonumber')

            if [[ $DURATION_MS -gt 0 && $DURATION_MS -gt $PC_DURATION_MS ]]; then
                TIME_INTEVAL_MS=$(expr $DURATION_MS - $PC_DURATION_MS)
                TIME_INTEVAL_SECS=$(echo "scale=4; $TIME_INTEVAL_MS / 1000" | bc | awk '{printf "%.4f", $0}')

                if [[ $TIME_INTEVAL_SECS == "0.0000" ]]; then
                    echo "UNKNOWN - Check run too quicly."
                    exit $UNKNOWN_RET
                fi
                #########################
                #  OUT Events
                #########################
                if [[ $OUT_EVENTS -gt 0 && $OUT_EVENTS -gt $PC_OUT_EVENTS ]]; then
                    DIFF_OUT_EVENTS=$(expr $OUT_EVENTS - $PC_OUT_EVENTS)
                    OUT_EVENT_PER_SECOND=$(echo "scale=1; $DIFF_OUT_EVENTS / $TIME_INTEVAL_SECS" | bc | awk '{printf "%.1f", $0}')
                else
                    #Logstash restart or other trouble
                    OUT_EVENT_PER_SECOND=0
                fi

                #########################
                #  IN Events
                #########################
                if [[ $IN_EVENTS -gt 0 && $IN_EVENTS -gt $PC_IN_EVENTS ]]; then
                    DIFF_IN_EVENTS=$(expr $IN_EVENTS - $PC_IN_EVENTS)
                    IN_EVENT_PER_SECOND=$(echo "scale=1; $DIFF_IN_EVENTS / $TIME_INTEVAL_SECS" | bc | awk '{printf "%.1f", $0}')
                else
                    #Logstash restart or other trouble
                    IN_EVENT_PER_SECOND=0
                fi
            else
                #Logstash restart or other trouble
                IN_EVENT_PER_SECOND=0
                OUT_EVENT_PER_SECOND=0
            fi

        else
            # A file with previous statistics does't exist! (First run or someone has delete it!)
            IN_EVENT_PER_SECOND=0
            OUT_EVENT_PER_SECOND=0
        fi

        ######################################################
        # Create or update file with current statistics
        ######################################################
        $(echo "$PARSED_RESP" > "$FILE_NAME")

        ########################
        # Evaluate results
        ########################
        if (( ${OUT_EVENT_PER_SECOND/\.*} > $MAX_CRIT )) && (( $MAX_CRIT != 0 )); then
            echo "CHECK CRITICAL - The number of events sent from Logstash is ${OUT_EVENT_PER_SECOND}EPS, above the ${MAX_CRIT}EPS in ${DURATION_W_H}h"
            echo "HOST: $HOST<br>"
            echo "IN events: $IN_EVENTS<br>"
            echo "OUT events: $OUT_EVENTS<br>"
            echo "Duration: ${DURATION_S}s.<br>"
            echo "EPS out: $OUT_EVENT_PER_SECOND<br>"
            echo "EPS in: $IN_EVENT_PER_SECOND<br>"
            echo " | 'outEps'=$OUT_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0; 'inEps'=$IN_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;"
            exit ${CRITICAL_RET}
        elif (( ${OUT_EVENT_PER_SECOND/\.*} < $MIN_CRIT )) && (( $MIN_CRIT != 0 )); then
            echo "CHECK CRITICAL - The number of events sent from Logstash is ${OUT_EVENT_PER_SECOND}EPS, below the ${MIN_CRIT}EPS in ${DURATION_W_H}h"
            echo "HOST: $HOST<br>"
            echo "IN events: $IN_EVENTS<br>"
            echo "OUT events: $OUT_EVENTS<br>"
            echo "Duration: ${DURATION_S}s.<br>"
            echo "EPS out: $OUT_EVENT_PER_SECOND<br>"
            echo "EPS in: $IN_EVENT_PER_SECOND<br>"
            echo " | 'outEps'=$OUT_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0; 'inEps'=$IN_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;"
            exit ${CRITICAL_RET}
        elif (( ${OUT_EVENT_PER_SECOND/\.*} > $MAX_WARN )) && (( $MAX_WARN != 0 )); then
            echo "CHECK WARNING - The number of events sent from Logstash is ${OUT_EVENT_PER_SECOND}EPS, above the ${MAX_WARN}EPS in ${DURATION_W_H}h"
            echo "HOST: $HOST<br>"
            echo "IN events: $IN_EVENTS<br>"
            echo "OUT events: $OUT_EVENTS<br>"
            echo "Duration: ${DURATION_S}s.<br>"
            echo "EPS out: $OUT_EVENT_PER_SECOND<br>"
            echo "EPS in: $IN_EVENT_PER_SECOND<br>"
            echo " | 'outEps'=$OUT_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0; 'inEps'=$IN_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;"
            exit ${WARNING_RET}
        elif (( ${OUT_EVENT_PER_SECOND/\.*} < $MIN_WARN )) && (( $MIN_WARN != 0 )); then
            echo "CHECK WARNING - The number of events sent from Logstash is ${OUT_EVENT_PER_SECOND}EPS, below the ${MIN_WARN}EPS in ${DURATION_W_H}h"
            echo "HOST: $HOST<br>"
            echo "IN events: $IN_EVENTS<br>"
            echo "OUT events: $OUT_EVENTS<br>"
            echo "Duration: ${DURATION_S}s.<br>"
            echo "EPS out: $OUT_EVENT_PER_SECOND<br>"
            echo "EPS in: $IN_EVENT_PER_SECOND<br>"
            echo " | 'outEps'=$OUT_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0; 'inEps'=$IN_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;"
            exit ${WARNING_RET}
        else
            echo "CHECK OK - The number of events sent from Logstash is ${OUT_EVENT_PER_SECOND}EPS in ${DURATION_W_H}h"
            echo "HOST: $HOST<br>"
            echo "IN events: $IN_EVENTS<br>"
            echo "OUT events: $OUT_EVENTS<br>"
            echo "Duration: ${DURATION_S}s.<br>"
            echo "EPS out: $OUT_EVENT_PER_SECOND<br>"
            echo "EPS in: $IN_EVENT_PER_SECOND<br>"
            echo " | 'outEps'=$OUT_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0; 'inEps'=$IN_EVENT_PER_SECOND;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;"
            exit ${OK_RET}
        fi
    fi
}

# Print the help message and exit
print_help() {
    echo "Version: $VERSION"
    echo ""
    echo "$PROGNAME checks Logstash events. Default run, it returns a global stats"
    echo ""
    echo "Examples:"
    echo "    $PROGNAME -P winlogbeat "
    echo "    $PROGNAME "
    echo ""
    echo "Options:"
    echo "  -h/--help"
    echo "     Print help."
    echo "  -P/--pipeline"
    echo "     Pipeline object of control."
    echo "  -c/--critical-threshold"
    echo "     the critical threshold in EPS (default: ${CRITICAL_THRESHOLD}, 0 to disable it)"
    echo "     Allowed formats: int."
    echo "  -w/--warning-threshold"
    echo "     the warning threshold in EPS (default: ${WARNING_THRESHOLD}, 0 to disable it)"
    echo "     Allowed formats: int."
    echo "  --logstash-host"
    echo "     the logstash host or ip (default: ${LS_HOST})"
    echo "     Allowed formats: str."
    echo "  --logstash-port"
    echo "     the elasticsearch port (default: ${LS_PORT})"
    echo "     Allowed formats: int."
    echo "  --logstash-protocol"
    echo "     the protocol used to connect to elasticsearch (default: ${LS_PROTOCOL})"
    echo "     Allowed formats: str."
}

#############
# Parse command line arguments
while test -n "$1"; do
    case "$1" in
    --logstash-host)
        LS_HOST=$2
        shift
        ;;
    --logstash-port)
        LS_PORT=$2
        shift
        ;;
    --logstash-protocol)
        LS_PROTOCOL=$2
        shift
        ;;
    -h | --help)
        print_help
        exit $UNKNOWN_RET
        ;;
    -w | --warning-threshold)
        WARNING_THRESHOLD=$2
        shift
        ;;
    -c | --critical-threshold)
        CRITICAL_THRESHOLD=$2
        shift
        ;;
    -P | --pipeline)
        PIPELINE=$2
        CHECK_PIPELINE=true
        DO_TOTAL_EPS=false
        shift
        ;;
    *)
        echo "UNKNOWN - $PROGNAME script executed with wrong argument."
        echo "Reason: unknown argument $1<br>"
        exit $UNKNOWN_RET
        ;;
    esac
    shift
done

if [[ $CHECK_PIPELINE == true && -z "${PIPELINE// /}" ]]; then
    echo "UNKNOWN - $PROGNAME script executed with wrong argument."
    echo "Reason: wrong --pipeline value.<br>"
    echo "Current: $PIPELINE<br>"
    echo "Allowed values: not empty value."
    exit $UNKNOWN_RET
fi

manage_nagios_range

check_threshold_existence "${MAX_WARN}" "${MAX_CRIT}"
check_threshold_existence "${MIN_WARN}" "${MAX_WARN}"

# Building Logstash request URL
URL="$LS_PROTOCOL://$LS_HOST:$LS_PORT"

LS_PATH_EVENTS_STATS="_node/stats/events"
LS_PATH_PIPELINES="_node/stats/pipelines"

if [[ $CHECK_PIPELINE == true ]]; then
    getPipelineDeatils
fi

if [[ $DO_TOTAL_EPS == true ]]; then
    getGlobalDeatils
fi
