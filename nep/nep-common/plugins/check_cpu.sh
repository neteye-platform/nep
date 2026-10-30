#!/bin/bash
# based on the script from:
# check_cpu.sh Copyright (C) 2017 https://github.com/sokecillo/nagios-check_cpu
# edited by ALEN

#Variables and defaults
STATE_OK=0              # define the exit code if status is OK
STATE_WARNING=1         # define the exit code if status is Warning
STATE_CRITICAL=2        # define the exit code if status is Critical
STATE_UNKNOWN=3         # define the exit code if status is Unknown

################################################################################
#Functions
help () {
echo -e "$0 $version (c) 2017-$(date +%Y) SoKeCiLLo and contributors (open source rulez!)

Usage: ./check_cpu.sh -w int -c int

Options:

   *  -w Warning threshold (percentage)
   *  -c Critical threshold (percentage)
      -h Help!

*mandatory options
"
exit $STATE_UNKNOWN;
}

thresholdlogic () {
if [ -n $WARN ] && [ -z $CRIT ]; then echo "UNKNOWN - Define both warning and critical thresholds"; exit $STATE_UNKNOWN; fi
if [ -n $CRIT ] && [ -z $WARN ]; then echo "UNKNOWN - Define both warning and critical thresholds"; exit $STATE_UNKNOWN; fi
}

################################################################################
# Check for people who need help - aren't we all nice ;-)
if [ "${1}" = "--help" -o "${#}" = "0" ]; then help; exit $STATE_UNKNOWN; fi
################################################################################
# Get user-given variables
while getopts "w:c:" Input
do
  case ${Input} in
  w)      WARN=${OPTARG};;
  c)      CRIT=${OPTARG};;
  *)      help;;
  esac
done


thresholdlogic


#Ensure warning is greater than critical limit
if [ $WARN -gt $CRIT ]
 then
  echo "Please ensure warning is greater than critical, eg."
  exit $STATE_UNKNOWN
fi


CPU_USAGE="$(vmstat 1 2|tail -1)"
CPU_USER="$(echo ${CPU_USAGE} | awk '{print $13}')"
CPU_SYSTEM="$(echo ${CPU_USAGE} | awk '{print $14}')"
CPU_IDLE="$(echo ${CPU_USAGE} | awk '{print $15}')"
CPU_IOWAIT="$(echo ${CPU_USAGE} | awk '{print $16}')"
CPU_ST="$(echo ${CPU_USAGE} | awk '{print $17}')"

TOTAL_USAGE=`expr $CPU_USER + $CPU_SYSTEM + $CPU_IOWAIT + $CPU_ST`

if [[ ${TOTAL_USAGE} -gt ${CRIT} ]]
then
  echo "CRITICAL - CPU total usage is ${TOTAL_USAGE}% |CPU_USER=${CPU_USER}%;;;0;100 CPU_SYSTEM=${CPU_SYSTEM}%;;;0;100  CPU_IOWAIT=${CPU_IOWAIT}%;;;0;100 CPU_ST=${CPU_ST}%;;;0;100 CPU_IDLE=${CPU_IDLE}%;;;0;100"
  exit $STATE_CRITICAL
elif [[ ${TOTAL_USAGE} -gt ${WARN} ]]
then
  echo "WARNING - CPU total usage is ${TOTAL_USAGE}% |CPU_USER=${CPU_USER}%;;;0;100 CPU_SYSTEM=${CPU_SYSTEM}%;;;0;100  CPU_IOWAIT=${CPU_IOWAIT}%;;;0;100 CPU_ST=${CPU_ST}%;;;0;100 CPU_IDLE=${CPU_IDLE}%;;;0;100"
  exit $STATE_WARNING
else
  echo "OK - CPU total usage is ${TOTAL_USAGE}% |CPU_USER=${CPU_USER}%;;;0;100 CPU_SYSTEM=${CPU_SYSTEM}%;;;0;100  CPU_IOWAIT=${CPU_IOWAIT}%;;;0;100 CPU_ST=${CPU_ST}%;;;0;100 CPU_IDLE=${CPU_IDLE}%;;;0;100"
  exit $STATE_OK
fi
