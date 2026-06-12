#!/bin/bash
##################################################################################
#
# Check-Script "check_sapcontrol.sh"
#
# Wrapper-Script for Checks using "sapcontrol"
#
#  History:
#  14.11.2019   initial version                  (Andreas Foerster)
#  07.04.2020   new function ABAPReadSyslog      (Andreas Foerster)
#  09.04.2020   Bugfixing                        (Andreas Foerster)
#               DIV by zero error, functions EnqGetStatistic/GetQueueStatistic;
#               output GetProcessList when using wrong host/inst-nr/protocol;
#  20.04.2020   function ABAPReadSyslog enhanced (Andreas Foerster)
#               scan field "Text" instead of field Message-Number (MNo)
#  21.04.2020   function ABAPReadSyslog enhanced (Andreas Foerster)
#               -exclude option added
#  05.05.2020   function ABAPReadSyslog enhanced (Andreas Foerster)
#               $SC_PATTERN is scanned by Perl REGEXP instead of awk REGEXP
#  08.11.2020   bugfix function ABAPGetWPTable (Andreas Foerster)
#               now working: CRITICAL Parameter when checking for PRIV-mode-WPs
#  17.01.2022   GetProcessList: Failed IGS will cause warning instead of critical
#  21.03.2022   explanation-text added for function ABAPReadSyslog enhanced (Andreas Foerster)
#  23.05.2023   ABAP Syslog-output: removed redundant lines (sort -u)
#  26.06.2023   sapcontrol binary moved to /neteye/shared/monitoring/software/sapcontrol (A.F.)
#
##################################################################################
#
#
# evaluate options
#
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -host)      SC_HOST="$2";     shift;;
    -nr)        SC_NR="$2";       shift;;
    -prot)      SC_PROT="$2";     shift;;
    -function)  SC_FUNCTION="$2"; shift;;
    -warn)      SC_WARN=$2;       shift;;
    -crit)      SC_CRIT=$2;       shift;;
    -pattern)   SC_PATTERN="$2";  shift;;
    -exclude)   SC_EXCLUDE="$2";  shift;;
    -lookback)  SC_LOOKBACK="$2"; shift;;
    -text)      SC_TEXT="$2";  shift;;
    *)          echo "UNKNOWN: Parameter not valid: $1"; exit 3;;
  esac
  shift
done
#
if ( [ -z "$SC_HOST" ] || [ -z "$SC_NR" ] || [ -z "$SC_FUNCTION" ] ); then
    echo "UNKNOWN: important parameters missing, usage:"
    echo "$(basename $0) -host <hostname> -nr <instance-no> -prot <NI_HTTPS|NI_HTTP> -function <webservice> [ -warn <value> -crit <value> -pattern <syslog search-pattern> -exclude <syslog search-pattern excluded> -lookback <hours>]"
    exit 3
fi
#
# set Variables
#
export LD_LIBRARY_PATH=/neteye/shared/monitoring/software/sapcontrol
export PATH=$PATH:$LD_LIBRARY_PATH
export TMP_FILE=/tmp/sapcontrol_$$
SC_HOST_SHORT=$(echo $SC_HOST | cut -d'.' -f 1)
PERF_OUT=""
#
case $SC_FUNCTION in
  GetVersionInfo)
    # get version-info
    sapcontrol -host $SC_HOST -nr $SC_NR -prot $SC_PROT -function $SC_FUNCTION | grep -e "changelist" > $TMP_FILE
    #
    LINE="$(grep "sapstartsrv" $TMP_FILE)"
    if [ -z "$LINE" ]; then
       RESULT=3
       STAT_OUT="UNKNOWN: Version information not found, please check host and instance-number"
    else
      # Unix or Windows?
      DIR_SEP='/'
      echo $LINE | awk '{print $1}' | grep -e '\\' >/dev/null && DIR_SEP='\'
      # SID ermitteln
      SID=$(echo $LINE | cut -d"$DIR_SEP" -f 4)
      # JAVA oder ABAP?
      TYP=$(echo $LINE | cut -d"$DIR_SEP" -f 5 | cut -c 1)
      # EXT-Kernel?
      EXT=""
      echo $LINE | cut -d',' -f 5 | grep EXT >/dev/null && EXT="_EXT"
      [ $TYP == A ] && SEARCHSTR="msg_server"
      [ $TYP == S ] && SEARCHSTR="msg_server"
      [ $TYP == D ] && SEARCHSTR="disp+work"
      [ $TYP == J ] && SEARCHSTR="jlaunch"
      KERNEL_VERSION="$(grep "$SEARCHSTR" $TMP_FILE | cut -d',' -f 2 | cut -d' ' -f 2)$EXT"
      KERNEL_PATCH=$(grep  "$SEARCHSTR" $TMP_FILE | cut -d',' -f 3 | cut -d' ' -f 3)
      # DB2/Unix LIB:
      ( [ $TYP == D ] || [ $TYP == J ] ) && KERNEL_DB_LIB=$(grep "dbdb6slib" $TMP_FILE | cut -d',' -f 3 | cut -d' ' -f 3)
      #
      PERF_OUT=""
      STATUS="OK"
      RESULT=0
      STAT_OUT=""
      if [ $TYP == D ]; then
        STAT_OUT="${STATUS}: Instance ${SC_HOST_SHORT}_${SID}_${SC_NR}: Kernel $KERNEL_VERSION, Patch $KERNEL_PATCH, DBSL $KERNEL_DB_LIB"
      else
        STAT_OUT="${STATUS}: Instance ${SC_HOST_SHORT}_${SID}_${SC_NR}: Kernel $KERNEL_VERSION, Patch $KERNEL_PATCH"
      fi
    fi
    rm -f $TMP_FILE
    ;;

  EnqGetStatistic)   \
    #
    # get enqueue-table and filter needed values
    #
    typeset -i LOCKS_NOW=0
    typeset -i LOCKS_HIGH=0
    typeset -i LOCKS_MAX=0
    LOCKS_STATE=""
    [ -z "$SC_WARN" ] && SC_WARN=80
    [ -z "$SC_CRIT" ] && SC_CRIT=90
    typeset -i WARN_PCT=$SC_WARN
    typeset -i CRIT_PCT=$SC_CRIT
    #
    read LOCKS_NOW LOCKS_HIGH LOCKS_MAX LOCKS_STATE < <(
    sapcontrol -host $SC_HOST -nr $SC_NR -prot $SC_PROT -function $SC_FUNCTION | awk '
     /^locks_now/ {printf "%s ",$2};
     /^locks_high/ {printf "%s ",$2};
     /^locks_max/ {printf "%s ",$2};
     /^locks_state/ {printf "%s\n",$2};')

    if [ $LOCKS_MAX -ne 0 ]; then
      # calculate values for output
      ((HIGH_PCT=100*${LOCKS_HIGH}/${LOCKS_MAX}))
      ((NOW_PCT=100*${LOCKS_NOW}/${LOCKS_MAX}))
      ((WARN=${LOCKS_MAX}*${WARN_PCT}/100))
      ((CRIT=${CRIT_PCT}*${LOCKS_MAX}/100))
      #
      STAT_OUT="OK: Current entries in lock-table: $LOCKS_NOW of $LOCKS_MAX (Peak since start of instance: $LOCKS_HIGH)"
      RESULT=0
      if [ $LOCKS_NOW -ge $WARN ] ; then
        STAT_OUT="WARNING: Current entries in lock-table: $LOCKS_NOW of $LOCKS_MAX (Peak since start of instance: $LOCKS_HIGH)"
        RESULT=1
        if [ $LOCKS_NOW -ge $CRIT ] ; then
          STAT_OUT="CRITICAL: Current entries in lock-table: $LOCKS_NOW of $LOCKS_MAX (Peak since start of instance: $LOCKS_HIGH)"
          RESULT=2
        fi
      fi
    else
      # something went wrong calling sapcontrol ...
      STAT_OUT="UNKNOWN: unable to read data, please check instance parameters"
      RESULT=3
    fi
    #
    PERF_OUT="'locks'=$LOCKS_NOW;$WARN;$CRIT;0;$LOCKS_MAX 'locks %'=$NOW_PCT%;$WARN_PCT;$CRIT_PCT"
    ;;

  GetQueueStatistic)    \
    #
    # get queue-status and filter needed values
    #
    typeset -i DIA_NOW=0
    typeset -i DIA_HIGH=0
    typeset -i DIA_MAX=0
    [ -z "$SC_WARN" ] && SC_WARN=70
    [ -z "$SC_CRIT" ] && SC_CRIT=90
    typeset -i WARN_PCT=$SC_WARN
    typeset -i CRIT_PCT=$SC_CRIT
    #
    read DIA_NOW DIA_HIGH DIA_MAX < <(
    sapcontrol -host $SC_HOST -nr $SC_NR -prot $SC_PROT -function $SC_FUNCTION | awk -F "," '
     /^ABAP\/DIA/ {printf "%s ",$2};
     /^ABAP\/DIA/ {printf "%s ",$3};
     /^ABAP\/DIA/ {printf "%s ",$4};')

    if [ $DIA_MAX -ne 0 ]; then
      # calculate values for output
      ((HIGH_PCT=100*${DIA_HIGH}/${DIA_MAX}))
      ((NOW_PCT=100*${DIA_NOW}/${DIA_MAX}))
      ((WARN=${DIA_MAX}*${WARN_PCT}/100))
      ((CRIT=${CRIT_PCT}*${DIA_MAX}/100))
      #
      STAT_OUT="OK: Requests in dialog-queue of dispatcher: $DIA_NOW of $DIA_MAX (Peak since start of DP: $DIA_HIGH)"
      RESULT=0
      if [ $DIA_NOW -ge $WARN ] ; then
        STAT_OUT="WARNING: Requests in dialog-queue of dispatcher: $DIA_NOW of $DIA_MAX (Peak since start of DP: $DIA_HIGH)"
        RESULT=1
        if [ $DIA_NOW -ge $CRIT ] ; then
          STAT_OUT="CRITICAL: Requests in dialog-queue of dispatcher: $DIA_NOW of $DIA_MAX (Peak since start of DP: $DIA_HIGH)"
          RESULT=2
        fi
      fi
    else
      # something went wrong calling sapcontrol ...
      STAT_OUT="UNKNOWN: unable to read data, please check instance parameters"
      RESULT=3
    fi
    #
    PERF_OUT="'queue-entries-dia'=$DIA_NOW;$WARN;$CRIT;0;$DIA_MAX 'queue-entries-dia %'=$NOW_PCT%;$WARN_PCT;$CRIT_PCT"
    ;;

  GetProcessList)    \
    #
    # Process status of instance
    #
    STAT_OUT=$(sapcontrol -host $SC_HOST -nr $SC_NR -prot $SC_PROT -function $SC_FUNCTION)
    RET=$?
    #
    #EXITCODES sapcontrol
    #    0  Last webmethod call successful
    #    1  Last webmethod call failed, invalid parameter
    #    2  StartWait, StopWait, WaitforStarted, WaitforStopped, RestartServiceWait
    #       timed out
    #    3  GetProcessList succeeded, all processes running correctly
    #    4  GetProcessList succeeded, all processes stopped
    #
    if [ -z "$(echo $STAT_OUT | grep "NIECONN_REFUSED")" ]; then
      RESULT=2
      [ $RET -eq 3 ] && RESULT=0
      # Start Change 17.01.2022
      if ( [ $RET -eq 0 ] && [ ! -z "$(echo "$STAT_OUT" | grep IGS | grep -i stopped)" ] ); then
        # Check for stopped IGS Processes:
        #declare -i all_procs=$(echo "$STAT_OUT" |wc -l)-5
        #declare -i run_procs=$(echo "$STAT_OUT" |grep -i running |wc -l)
        declare -i stop_procs=$(echo "$STAT_OUT" |wc -l)-5-$(echo "$STAT_OUT" |grep -i running |wc -l)
        if [ $stop_procs -eq 1 ]; then
          # If only IGS is stopped, change RESULT to 1 (WARNING)
          RESULT=1
        fi
        #
      fi
      # End Change 17.01.2022
      # Start Change 21.02.2023
      [ $RESULT -eq 2 ] && STAT_OUT=$(echo -e "SAP-Instance not running!\n${STAT_OUT}")
      # End Change 21.02.2023
    else
      RESULT=3
      STAT_OUT="unable to connect to sapstartsrv, please check instance parameters"
    fi
    ;;

  ABAPGetWPTable)    \
    #
    # count free dialog processes
    #
    sapcontrol -host $SC_HOST -nr $SC_NR -prot $SC_PROT -function $SC_FUNCTION | grep -e "^No" -e "^[0-9]*," >$TMP_FILE
    DIA_TOTAL=$(cat $TMP_FILE | grep DIA | wc -l)
    DIA_FREE=$(cat $TMP_FILE | grep DIA | grep Wait | wc -l)
    #
    # count dialog processes being in PRIV-mode
    # (to switch to PRIV-mode checking set option "-pattern" to "PRIV")
    #
    DIA_PRIV=$(cat $TMP_FILE | grep DIA | grep PRIV | wc -l)

    if [ $DIA_TOTAL -eq 0 ]; then
      # something went wrong, perhaps system is down ...
      STAT_OUT="UNKNOWN: Unable to read WP-Table, please check system or instance parameters"
      PERF_OUT=""
      RESULT=3
    else
      RESULT=0
      if [ "$SC_PATTERN" = "PRIV" ]; then
        STAT_OUT="OK: No dialog processes in PRIV-mode"
        if [ $DIA_PRIV -ge $SC_WARN ] ; then
          STAT_OUT="WARNING: $DIA_PRIV DIALOG-Process(es) in PRIV-Mode, number of free dialog processes: $DIA_FREE of $DIA_TOTAL"
          RESULT=1
          if [ $DIA_PRIV -ge $SC_CRIT ] ; then
          STAT_OUT="CRITICAL $DIA_PRIV DIALOG-Process(es) in PRIV-Mode, number of free dialog processes: $DIA_FREE of $DIA_TOTAL"
          RESULT=2
          fi
        fi
        STAT_OUT="${STAT_OUT}\n$(grep PRIV $TMP_FILE)"
        PERF_OUT="'wp-dia-priv'=$DIA_PRIV;$SC_WARN;$SC_CRIT;0;$DIA_TOTAL"
      else
        STAT_OUT="OK: Number of free dialog processes: $DIA_FREE of $DIA_TOTAL"
        if [ $DIA_FREE -le $SC_WARN ] ; then
          STAT_OUT="WARNING: Number of free dialog processes: $DIA_FREE of $DIA_TOTAL"
          RESULT=1
          if [ $DIA_FREE -le $SC_CRIT ] ; then
          STAT_OUT="CRITICAL: Number of free dialog processes: $DIA_FREE of $DIA_TOTAL"
            RESULT=2
          fi
        fi
        STAT_OUT="${STAT_OUT}\nCurrent Workprocess-Table:\n$(cat $TMP_FILE)"
        PERF_OUT="'wp-dia-free'=$DIA_FREE;$SC_WARN;$SC_CRIT;0;$DIA_TOTAL"
      fi
    fi
    rm -f $TMP_FILE
    ;;

  ABAPReadSyslog)    \
    #
    # analyze syslog, search for pattern
    #
    if [ -z "$SC_PATTERN" ]; then
      STAT_OUT="UNKNOWN: For using function \"ABABReadSyslog\" please specify option \"-pattern <search-pattern>\" for SYSLOG Text"
      RESULT=3
    else
      [ -z "$SC_LOOKBACK" ] && SC_LOOKBACK=1440    # default lookback: 24*60m
      SYSTIME=$(date)
      # export LOOKBACK, SC_EXCLUDE and SC_PATTERN for perl
      export LOOKBACK=$(date -d "$SYSTIME - $SC_LOOKBACK minutes" +"%Y %m %d %H:%M:%S")
      export SC_PATTERN
      if [ -z $SC_EXCLUDE ]; then
        # use perl REGEX for search-pattern (05.05.2020, A. Foerster)
        sapcontrol -host $SC_HOST -nr $SC_NR -prot $SC_PROT -function $SC_FUNCTION | perl -F',' -lane 'print if (($F[6] =~ /$ENV{SC_PATTERN}/)&&($F[0] gt $ENV{LOOKBACK}))' | sort -u >$TMP_FILE
      else
        export SC_EXCLUDE
        # use perl REGEX for search-pattern (05.05.2020, A. Foerster)
        sapcontrol -host $SC_HOST -nr $SC_NR -prot $SC_PROT -function $SC_FUNCTION | perl -F',' -lane 'print if (($F[6] =~ /$ENV{SC_PATTERN}/)&&($F[0] gt $ENV{LOOKBACK})&&($F[6] !~ /$ENV{SC_EXCLUDE}/))' | sort -u >$TMP_FILE
      fi
      if [ "$SC_TEXT" != "" ]; then
        OUT_STRING="$SC_TEXT"
      else
        OUT_STRING="text pattern $(echo $SC_PATTERN | /usr/bin/sed -e 's/|/\ or\ /g')"
      fi
      if [ -s $TMP_FILE ]; then
        STAT_OUT="WARNING: Syslog entries found for ${OUT_STRING}:\n$(cat $TMP_FILE)"
        RESULT=1
      else
        STAT_OUT="OK: No Syslog entries found for ${OUT_STRING}"
        RESULT=0
      fi
      rm -f $TMP_FILE
    fi
    ;;

  *)  \
    STAT_OUT="UNKNOWN: Function not implemented: $SC_FUNCTION"
    RESULT=3
    ;;
esac

echo -e "${STAT_OUT}\c"
if [ "$PERF_OUT" != "" ];then
  echo "|${PERF_OUT}"
else
  echo
fi
exit $RESULT
