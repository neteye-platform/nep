#!/usr/bin/python3
####################################################
# Copyright Wuerth-Phoenix                         #
# This script can be distributed under GPL License #
# Author: ALEN & SOC Team                          #
####################################################

# This script will help in configuring a customer items on Elastic Infrastructure
# It support also deletions of customer spaces.

import argparse, requests, sys, os
import logging
import json
from datetime import datetime, timedelta

# Disable warning for Self Signed Certs
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

headers = {"Content-Type": "application/json"}
cert_path = "/neteye/local/elasticsearch/conf/monitoring-certs/certs/"
cert_file = "NetEyeElasticCheck.crt.pem"
key_file = "private/NetEyeElasticCheck.key.pem"

OK_CODE = 0
WARNING_CODE = 1
CRITICAL_CODE = 2
UNKNOWN_CODE = 3

### START FUNCTIONS ###

def CalculateEPS(events:int, interval:str):
    if events <= 0:
        logging.debug("No events in the interval")
        eps = 0
    else:
        # Convert interval to secs
        if interval[-1] == "m":
            seconds = int(interval[:-1]) * 60
        elif interval[-1] == "h":
            seconds = int(interval[:-1]) * 3600
        elif interval[-1] == "d":
            seconds = int(interval[:-1]) * 86400

        eps = round(events / seconds, 1)
    return eps

### END FUNCTIONS ###

### MAIN ####
__version__ = '0.0.1'
__version_date__ = '2024-01-23'


# Arguments definition
parser = argparse.ArgumentParser(description="Check status of Snapshot Lificycle Management (SLM) into Elasticsearch")
parser.add_argument("-V", "--version", help="show program version", action="store_true")
parser.add_argument('-v', '--verbose', help="enable verbose mode", action='store_true')
parser.add_argument("-t", "--type", dest="CheckType", type=str.lower, default='status', choices=['status', 'policy']),
parser.add_argument("-f", "--filters", dest="Filters", type=str, action='append', nargs='+', help='Filters to be added on query match, this param can be use multiple times (format: field.name=value)')
parser.add_argument("-w", "--warning", dest="WarningThresold", type=str, default='24h', help='Warning threshold time from last succesfull policy execution')
parser.add_argument("-c", "--critical", dest="CriticalThresold", type=str, default='48h', help='Critical threshold time from last succesfull policy execution')

# Read arguments from command line
args = parser.parse_args()

if args.version:
    print(__version__)
if args.verbose:
    logging.basicConfig(level=logging.DEBUG)
else:
    logging.basicConfig(level=logging.INFO)

# convert thresolds
if args.WarningThresold[-1] == 'd':
    warn_seconds = int(args.WarningThresold[:-1]) * 86400
elif args.WarningThresold[-1] == 'h':
    warn_seconds = int(args.WarningThresold[:-1]) * 3600
elif args.WarningThresold[-1] == 'm':
    warn_seconds = int(args.WarningThresold[:-1])
else:
    message = "UNKNOWN - Warning threshold format '" + args.WarningThresold[-1] + "' not supported. Valid format are: 'd', 'h', 'm'."
    print(message)
    sys.exit(3)
if args.CriticalThresold[-1] == 'd':
    crit_seconds = int(args.CriticalThresold[:-1]) * 86400
elif args.CriticalThresold[-1] == 'h':
    crit_seconds = int(args.CriticalThresold[:-1]) * 3600
elif args.CriticalThresold[-1] == 'm':
    crit_seconds = int(args.CriticalThresold[:-1])
else:
    message = "UNKNOWN - Critical threshold format '" + args.CriticalThresold[-1] + "' not supported. Valid format are: 'd', 'h', 'm'."
    print(message)
    sys.exit(3)

if warn_seconds < 0 or crit_seconds < 0:
    message = "UNKNOWN - Threshold cannot be a negative number."
    print(message)
    sys.exit(3)
if warn_seconds > crit_seconds:
    message = "UNKNOWN - Warning threshold cannot be higher then Critial threshold."
    print(message)
    sys.exit(3)

# Set logger
logger = logging.getLogger()

URL = "https://elasticsearch.neteyelocal:9200/"

# Check Status
if args.CheckType == 'status':
    r = requests.get(URL + "_slm/status", headers=headers, cert=(cert_path + cert_file,cert_path + key_file), verify=False)
    if r.status_code == 200:
        logging.debug(r.content)
        JSON_RES = json.loads(r.content)
        STATUS = JSON_RES['operation_mode']

        if STATUS == "STOPPED":
            EXIT_CODE = CRITICAL_CODE
            message = "CRITICAL - Snapshot Lifecycle Management (SLM) status is " + STATUS
        if STATUS == "STOPPING":
            EXIT_CODE = WARNING_CODE
            message = "WARNING - Snapshot Lifecycle Management (SLM) status is " + STATUS
        if STATUS == "RUNNING":
            EXIT_CODE = OK_CODE
            message = "OK - Snapshot Lifecycle Management (SLM) status is " + STATUS

    else:
        ## Error on Elastic
        EXIT_CODE = UNKNOWN_CODE

# Check Policies
if args.CheckType == 'policy':
    EXIT_CODE = OK_CODE

    r = requests.get(URL + "_slm/policy", headers=headers, cert=(cert_path + cert_file,cert_path + key_file), verify=False)
    if r.status_code == 200:
        logging.debug(r.content)
        JSON_RES = json.loads(r.content)
        tmp_message = ""
        # iterate over policies
        count = 0
        for policy in JSON_RES:
            tmp_message += "--- START POLICY ---<br>"

            stats = JSON_RES[policy]['stats']
            tmp_message += "Stats: taken " + str(stats['snapshots_taken']) + " - failed " + str(stats['snapshots_failed']) + " - deleted " + str(stats['snapshots_deleted']) + "<br>"
            # stats['snapshot_deletion_failures']

            if 'last_failure' in JSON_RES[policy]:
                tmp_message += "Last Failure: " + str(datetime.fromtimestamp(JSON_RES[policy]['last_failure']['time'] / 1000)) + "<br>"
            if 'last_success' in JSON_RES[policy]:
                success_time = datetime.fromtimestamp(JSON_RES[policy]['last_success']['time'] / 1000)
                tmp_message += "Last Success: " + str(success_time) + "<br>"
                ## check threshold
                if datetime.now() - timedelta(seconds=crit_seconds) > success_time:
                    EXIT_CODE = CRITICAL_CODE
                    tmp_message += "[CRITICAL] Policy named '" + policy + "' not correctly executed in the last " + args.CriticalThresold + "<br>"
                elif datetime.now() - timedelta(seconds=warn_seconds) > success_time:
                    if EXIT_CODE != CRITICAL_CODE:
                        EXIT_CODE = WARNING_CODE
                    tmp_message += "[WARNING] Policy named '" + policy + "' not correctly executed in the last " + args.WarningThresold + "<br>"
                else:
                    tmp_message += "[OK] Policy named '" + policy + "' works fine" + "<br>"
            tmp_message += "--- END POLICY ---<br>"
            count += 1

    if EXIT_CODE == CRITICAL_CODE:
        message = "CRITICAL - Snapshot Lifecycle Management (SLM) policies has some error.\n"
    if EXIT_CODE == WARNING_CODE:
        message = "WARNING - Snapshot Lifecycle Management (SLM) policies has some error.\n"
    if EXIT_CODE == OK_CODE:
        message = "OK - Snapshot Lifecycle Management (SLM) policies work fine.\n"

    message+= tmp_message + "|'policies'=" + str(count) + ";;;0;"

#################
# Icinga output #
#################

## Common message

if args.Filters:
    message += "Filters: " + str(args.Filters) + "<br>"

# Perf data
#message += "| 'TotalEvents'=" + str(TOTAL_EVENTS) + ";;;0; 'TotalEps'=" + str(total_result) + ";" + str(args.WarningThresold) + ";" + str(args.CriticalThresold) + ";0;"

## UNKNOW (error on api)
if EXIT_CODE == UNKNOWN_CODE:
    message = "UNKNOWN - Elasticsearch API error.\nStatus Code: " + str(r.status_code) + "<br>Reason: " + str(r.content)

# Return message and exit code
print(message)
sys.exit(EXIT_CODE)