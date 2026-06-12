#!/bin/bash

#
# Version: X
# Developed by XXX
#

# 1) Controllare numero accessi
# 2) max response non superi soglia
# 2) max task per kibana istances

# ?? gestire più istanze kibana

PROGNAME=$(basename $0)
VERSION="1"

#VariablKB and defaults
STATE_OK=0              # define the exit code if status is OK
STATE_WARNING=1         # define the exit code if status is Warning
STATE_CRITICAL=2        # define the exit code if status is Critical
STATE_UNKNOWN=3         # define the exit code if status is Unknown

# Kibana config options
port=5601
httpscheme=http
max_time=30


DO_CONCURRENT_CONNECTIONS=false
DO_MAX_RESPONSE_TIME=false

help () {
echo -e "$0 $version (c) 2022-$(date +%Y) chicco27  and contributors (open source rulez!)

Usage: ./$PROGNAME -H KBNode [-P port] [-S] [-u user -p pass|-K api_key] -t checktype [-w int] [-c int] [-m int]

Options:

   *  -H Hostname or ip address of ElasticSearch Node
      -P Port (defaults to 5601)
      -S Use https
      -K API Key file for Authentication (absolute path)
      -u Username if authentication is required
      -p Password if authentication is required
   *  -t Type of check (rt, task)
      -w Warning threshold (see usage notes below)
      -c Critical threshold (see usage notes below)
      -m Maximum time in seconds to wait for response (default: 30)
      -h Help!

*mandatory options

Threshold format for max_response_time': int, milliseconds

)"
exit $STATE_UNKNOWN;
}

authlogic () {
if [[ -z $user ]] && [[ -z $pass ]]; then echo "KB SYSTEM UNKNOWN - Authentication required but missing username and password"; exit $STATE_UNKNOWN
elif [[ -n $user ]] && [[ -z $pass ]]; then echo "KB SYSTEM UNKNOWN - Authentication required but missing password"; exit $STATE_UNKNOWN
elif [[ -n $pass ]] && [[ -z $user ]]; then echo "KB SYSTEM UNKNOWN - Missing username"; exit $STATE_UNKNOWN
fi
}

runquery () {
    if [[ -z $user ]] && [[ -z $key ]]; then
    # Without authentication
    response=$(curl -k -s --max-time ${max_time} $kburl)
    responserc=$?
    if [[ $responserc -eq 7 ]]; then
        echo "KB SYSTEM CRITICAL - Failed to connect to ${host} port ${port}: Connection refused"
        exit $STATE_CRITICAL
    elif [[ $responserc -eq 28 ]]; then
        echo "KB SYSTEM CRITICAL - server did not respond within ${max_time} seconds"
        exit $STATE_CRITICAL
    elif [[ "$response" =~ "503 Service Unavailable" ]]; then
        echo "KB SYSTEM CRITICAL - Kibana not available: ${host}:${port} return error 503"
        exit $STATE_CRITICAL
    elif [[ "$response" =~ "Unknown resource" ]]; then
        echo "KB SYSTEM CRITICAL - Kibana not available: ${response}"
        exit $STATE_CRITICAL
    elif ! [[ "$response" =~ "cluster_name" ]]; then
        echo "KB SYSTEM CRITICAL - Kibana not available at this address ${host}:${port}"
        exit $STATE_CRITICAL
    fi
    fi

    if [[ -n $user ]] ; then
    # Authentication required
    authlogic
    response=$(curl -k -s --max-time ${max_time} --basic -u ${user}:${pass} $kburl)
    responserc=$?
    if [[ $responserc -eq 7 ]]; then
        echo "KB SYSTEM CRITICAL - Failed to connect to ${host} port ${port}: Connection refused"
        exit $STATE_CRITICAL
    elif [[ $responserc -eq 28 ]]; then
        echo "KB SYSTEM CRITICAL - server did not respond within ${max_time} seconds"
        exit $STATE_CRITICAL
    elif [[ "$response" =~ "503 Service Unavailable" ]]; then
        echo "KB SYSTEM CRITICAL - Kibana not available: ${host}:${port} return error 503"
        exit $STATE_CRITICAL
    elif [[ "$response" =~ "Unknown resource" ]]; then
        echo "KB SYSTEM CRITICAL - Kibana not available: ${response}"
        exit $STATE_CRITICAL
    elif [[ -n $(echo "$response" | grep -i "unable to authenticate") ]]; then
        echo "KB SYSTEM CRITICAL - Unable to authenticate user $user for REST request"
        exit $STATE_CRITICAL
    elif [[ -n $(echo "$response" | grep -i "unauthorized") ]]; then
        echo "KB SYSTEM CRITICAL - User $user is unauthorized"
        exit $STATE_CRITICAL
    elif ! [[ "$response" =~ "cluster_name" ]]; then
        echo "KB SYSTEM CRITICAL - Kibana not available at this address ${host}:${port}"
        exit $STATE_CRITICAL
    fi
    fi

    if [[ -n $key ]] ; then
    # Authentication with API keys
    response=$(curl -k -s --max-time ${max_time} -H "Authorization:ApiKey ${key}" $kburl)
    responserc=$?
    if [[ $responserc -eq 7 ]]; then
        echo "KB SYSTEM CRITICAL - Failed to connect to ${host} port ${port}: Connection refused"
        exit $STATE_CRITICAL
    elif [[ $responserc -eq 28 ]]; then
        echo "KB SYSTEM CRITICAL - server did not respond within ${max_time} seconds"
        exit $STATE_CRITICAL
    elif [[ "$response" =~ "503 Service Unavailable" ]]; then
        echo "KB SYSTEM CRITICAL - Kibana not available: ${host}:${port} return error 503"
        exit $STATE_CRITICAL
    elif [[ -n $(echo "$response" | grep -i "unable to authenticate") ]]; then
        echo "KB SYSTEM CRITICAL - Unable to authenticate user $user for REST request"
        exit $STATE_CRITICAL
    elif [[ -n $(echo "$response" | grep -i "unauthorized") ]]; then
        echo "KB SYSTEM CRITICAL - User $user is unauthorized"
        exit $STATE_CRITICAL
    fi
    fi

    # Catch empty reply from server (typically happens when ssl port used with http connection)
    if [[ -z $response ]] || [[ $response = '' ]]; then
    echo "KB SYSTEM UNKNOWN - Empty reply from server (verify ssl settings)"
    exit $STATE_UNKNOWN
    fi

}

################################################################################
# Check for people who need help - aren't we all nice ;-)
if [ "${1}" = "--help" -o "${#}" = "0" ]; then help; exit $STATE_UNKNOWN; fi
################################################################################
# Get user-given variables
while getopts "H:P:SK:u:p:i:w:c:m:t:" Input
do
  case ${Input} in
  H)      host=${OPTARG};;
  P)      port=${OPTARG};;
  S)      httpscheme=https;;
  K)      key_file=${OPTARG};;
  u)      user=${OPTARG};;
  p)      pass=${OPTARG};;
  i)      include=${OPTARG};;
  w)      warning=${OPTARG};;
  c)      critical=${OPTARG};;
  m)      max_time=${OPTARG};;
  t)      checktype=${OPTARG};;
  *)      help;;
  esac
done

# Check for mandatory opts
if [[ -z ${host} ]]; then help; exit $STATE_UNKNOWN; fi
if [[ -z ${checktype} ]]; then help; exit $STATE_UNKNOWN; fi

# Check key file
if [[ -n ${key_file} ]]; then
    key=$(cat $key_file | jq -r '.encoded')
fi


#################################################
#################################################
case $checktype in
rt) # Check Max Response Time

    if [[ -n $warning ]] && ! [[ $warning =~ ^([0-9]+)$ ]]; then
        echo "UNKNOWN - $PROGNAME script executed with wrong argument."
        echo "Reason: wrong warning value for Max Response Time.<br>"
        echo "Current: $warning<br>"
        echo "Allowed values:^([0-9]+)$.<br>"
        exit $STATE_UNKNOWN
    fi
    if [[ -n $critical ]] && ! [[ $critical =~ ^([0-9]+)$ ]]; then
        echo "UNKNOWN - $PROGNAME script executed with wrong argument."
        echo "Reason: wrong critical value for Max Response Time.<br>"
        echo "Current: $critical<br>"
        echo "Allowed values:^([0-9]+)$.<br>"
        exit $STATE_UNKNOWN
    fi


    kburl="${httpscheme}://${host}:${port}/api/stats"

    runquery

    PARSED_RESP=$(echo "$response" | jq -c '. | {total_requests: .requests.total , max_response_times: .response_times.max_ms , concurrent_connections: .concurrent_connections , collection_interval_ms: .collection_interval_ms}')

    MRS=$(echo "$PARSED_RESP" | jq -c '.max_response_times')
    CC=$(echo "$PARSED_RESP" | jq -c '.concurrent_connections')
    TR=$(echo "$PARSED_RESP" | jq -c '.total_requests')
    CI_MS=$(echo "$PARSED_RESP" | jq -c '.collection_interval_ms')

    if [[ $MRS != null ]]; then
        MRS_N=$(echo "$MRS" | jq -c 'tonumber')
        if [[ $MRS_N -ge $critical ]] && [[ -n $critical ]]; then
            echo "CRITICAL - Kibana's max_response_time ${MRS_N}ms exceded the thresold ${critical}ms"
            echo "Max response time : ${MRS_N}ms<br>"
            echo "Total requests: $TR<br>"
            echo "Concurrent connections: $CC<br>"
            echo "Connection interval: ${CI_MS}ms<br>"
            echo " | 'max_response_time'=${MRS_N}ms;${warning}ms;${critical}ms;0; 'requests'=$TR;;;0; 'connections'=$CC;;;0;"
            exit $STATE_CRITICAL
        elif [[ $MRS_N -ge $warning ]] && [[ -n $warning ]]; then
            echo "WARNING - Kibana's max_response_time ${MRS_N}ms exceded the thresold ${warning}ms"
            echo "Max response time : ${MRS_N}ms<br>"
            echo "Total requests: $TR<br>"
            echo "Concurrent connections: $CC<br>"
            echo "Connection interval: ${CI_MS}ms<br>"
            echo " | 'max_response_time'=${MRS_N}ms;${warning}ms;${critical}ms;0; 'requests'=$TR;;;0; 'connections'=$CC;;;0;"
            exit $STATE_WARNING
        else
            echo "OK - Kibana's max_response_time ${MRS_N}ms"
            echo "Max response time : ${MRS_N}ms<br>"
            echo "Total requests: $TR<br>"
            echo "Concurrent connections: $CC<br>"
            echo "Connection interval: ${CI_MS}ms<br>"
            echo " | 'max_response_time'=${MRS_N}ms;${warning}ms;${critical}ms;0; 'requests'=$TR;;;0; 'connections'=$CC;;;0;"
            exit $STATE_OK
        fi
    else
        echo "UNKNOWN - Error during max_response_time evaluation."
        echo "Reason: the value of max_response_time is null.<br>"
        echo "Current: null<br>"
        exit $STATE_UNKNOWN
    fi

    ;;

task) ## Task Manager

    # By default, this setting marks the health of every task type as warning when it exceeds 80% failed executions,
    # and as error at 90%. Set this value to a number between 0 to 100. The threshold is hit when the value exceeds this number.
    # To avoid a status of error, set the threshold at 100. To hit error the moment any task fails, set the threshold to 0.

    kburl="${httpscheme}://${host}:${port}/api/task_manager/_health"

    runquery

    # The Capacity Estimation status indicates the sufficiency of the observed capacity.
    # An OK status means capacity is sufficient.
    # A Warning status means that capacity is sufficient for the scheduled recurring tasks, but non-recurring tasks often cause the cluster to exceed capacity.
    # An Error status means that there is insufficient capacity across all types of tasks.

    KB_CAPACITY=$(echo "$response" |  jq '.stats.capacity_estimation' )

    CAPACITY_STATUS=$(echo "$KB_CAPACITY" | jq -r '.status')
    KB_INSTANCE=$(echo "$KB_CAPACITY" | jq -r '.value.observed.observed_kibana_instances')
    KB_MAX_TPM=$(echo "$KB_CAPACITY" | jq -r '.value.observed.max_throughput_per_minute')
    KB_MTDO=$(echo "$KB_CAPACITY" | jq -r '.value.observed.minutes_to_drain_overdue')
    KB_AVG_RECURRING_TPM=$(echo "$KB_CAPACITY" | jq -r '.value.observed.avg_recurring_required_throughput_per_minute')
    KB_AVG_REQUIRED_TPM=$(echo "$KB_CAPACITY" | jq -r '.value.observed.avg_required_throughput_per_minute')

    KB_REQUIRED_INSTANCE=$(echo "$KB_CAPACITY" | jq -r '.value.proposed.min_required_kibana')
    KB_SUGGEST_INSTANCE=$(echo "$KB_CAPACITY" | jq -r '.value.proposed.provisioned_kibana')


    KB_CONFIGURATION=$(echo "$response" |  jq '.stats.configuration' )
    CONF_STATUS=$(echo "$KB_CONFIGURATION" | jq -r '.status')
    KB_TASK_CRIT_THRESHOLDS=$(echo "$KB_CONFIGURATION" | jq -r '.value.monitored_task_execution_thresholds.default.error_threshold')
    KB_TASK_WARN_THRESHOLDS=$(echo "$KB_CONFIGURATION" | jq -r '.value.monitored_task_execution_thresholds.default.warn_threshold')

    if [ $CAPACITY_STATUS == "ERROR" ]; then
        echo "CRITICAL - Kibana Task manager as insufficient capacity across all types of tasks, based on warning threshold of $KB_TASK_WARN_THRESHOLDS% and critical threshold of $KB_TASK_CRIT_THRESHOLDS%.<br>"
        echo "The maximum available throughput overall Kibana instance is '$KB_MAX_TPM' tasks per minute (splitted on $KB_INSTANCE Kibana instance).<br>"
        echo "Based on past throughput the overdue tasks in the system could be executed within '$KB_MTDO' minute.<br>"
        echo "On average, the RECURRING tasks in the system have historically required a throughput of '$KB_AVG_RECURRING_TPM' tasks per minute. Instead the overall tasks (recurring or otherwise) have historically required a throughput of '$KB_AVG_REQUIRED_TPM' tasks per minute.<br><br>"
        echo "Estimated deployment strategy from Kibana: a minimin of '$KB_REQUIRED_INSTANCE' Kibana instance is required for current workload, the suggested number of instance are '$KB_SUGGEST_INSTANCE'."
        echo " | 'instances'=$KB_INSTANCE;;;; 'max_throughput_per_minute'=$KB_MAX_TPM;;;; 'minutes_to_drain_overdue'=${KB_MTDO}m;;;; 'avg_recurring_throughput_per_minute'=$KB_AVG_RECURRING_TPM;;;; 'avg_required_throughput_per_minute'=$KB_AVG_REQUIRED_TPM;;;;"
        exit $STATE_CRITICAL
    elif [ $CAPACITY_STATUS == "WARNING" ]; then
        echo "WARNING - Kibana Task manager capacity is sufficient for the scheduled recurring tasks, but non-recurring tasks often cause the cluster to exceed capacity. This is based on warning threshold of $KB_TASK_WARN_THRESHOLDS% and critical threshold of $KB_TASK_CRIT_THRESHOLDS%.<br>"
        echo "The maximum available throughput overall Kibana instance is '$KB_MAX_TPM' tasks per minute (splitted on $KB_INSTANCE Kibana instance).<br>"
        echo "Based on past throughput the overdue tasks in the system could be executed within '$KB_MTDO' minute.<br>"
        echo "On average, the RECURRING tasks in the system have historically required a throughput of '$KB_AVG_RECURRING_TPM' tasks per minute. Instead the overall tasks (recurring or otherwise) have historically required a throughput of '$KB_AVG_REQUIRED_TPM' tasks per minute.<br><br>"
        echo "Estimated deployment strategy from Kibana: a minimin of '$KB_REQUIRED_INSTANCE' Kibana instance is required for current workload, the suggested number of instance are '$KB_SUGGEST_INSTANCE'."
        echo " | 'instances'=$KB_INSTANCE;;;; 'max_throughput_per_minute'=$KB_MAX_TPM;;;; 'minutes_to_drain_overdue'=${KB_MTDO}m;;;; 'avg_recurring_throughput_per_minute'=$KB_AVG_RECURRING_TPM;;;; 'avg_required_throughput_per_minute'=$KB_AVG_REQUIRED_TPM;;;;"
        exit $STATE_WARNING

    elif [ $CAPACITY_STATUS == "OK" ]; then
        echo "OK - Kibana Task manager as sufficient capacity, based on warning threshold of $KB_TASK_WARN_THRESHOLDS% and critical threshold of $KB_TASK_CRIT_THRESHOLDS%.<br>"
        echo "The maximum available throughput overall Kibana instance is '$KB_MAX_TPM' tasks per minute (splitted on $KB_INSTANCE Kibana instance).<br>"
        echo "Based on past throughput the overdue tasks in the system could be executed within '$KB_MTDO' minute.<br>"
        echo "On average, the RECURRING tasks in the system have historically required a throughput of '$KB_AVG_RECURRING_TPM' tasks per minute. Instead the overall tasks (recurring or otherwise) have historically required a throughput of '$KB_AVG_REQUIRED_TPM' tasks per minute.<br><br>"
        echo "Estimated deployment strategy from Kibana: a minimin of '$KB_REQUIRED_INSTANCE' Kibana instance is required for current workload, the suggested number of instance are '$KB_SUGGEST_INSTANCE'."
        echo " | 'instances'=$KB_INSTANCE;;;; 'max_throughput_per_minute'=$KB_MAX_TPM;;;; 'minutes_to_drain_overdue'=${KB_MTDO}m;;;; 'avg_recurring_throughput_per_minute'=$KB_AVG_RECURRING_TPM;;;; 'avg_required_throughput_per_minute'=$KB_AVG_REQUIRED_TPM;;;;"
        exit $STATE_OK
    else
        echo "UNKNOWN - Kibana task manager as unadled error. Check correct configuration on Kibana."
        exit $STATE_UNKNOWN
    fi

    ;;

esac
