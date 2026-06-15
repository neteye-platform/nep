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

from requests.exceptions import ReadTimeout, ConnectionError

# Disable warning for Self Signed Certs
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

headers = {"Content-Type": "application/json"}
cert_path = "/neteye/local/elasticsearch/conf/monitoring-certs/certs/"
cert_file = "NetEyeElasticCheck.crt.pem"
key_file = "private/NetEyeElasticCheck.key.pem"
message = ""

OK_CODE = 0
WARNING_CODE = 1
CRITICAL_CODE = 2
UNKNOWN_CODE = 3
TOTAL_EVENTS = 0

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
__version__ = '0.3.1'
__version_date__ = '2023-07-23'


# Arguments definition
parser = argparse.ArgumentParser(description="Check data receiving into Elasticsearch based on agent and filters")
parser.add_argument("-V", "--version", help="show program version", action="store_true")
parser.add_argument('-v', '--verbose', help="enable verbose mode", action='store_true')
parser.add_argument("-a", "--agent", dest="AgentType", type=str.lower, default='all', choices=['winlogbeat', 'filebeat', 'auditbeat', 'packetbeat', 'metricbeat', 'elastic_agent', 'logstash', 'all'], help='Choose agent type for check (default: %(default)s)')
parser.add_argument("-t", "--tenant", dest="TenantId", type=str, required=True, help='Tenant ID where search data (like namespace for ElasticAgent)')
parser.add_argument("-f", "--filters", dest="Filters", type=str, action='append', nargs='+', help='Filters to be added on query match, this param can be use multiple times (format: field.name=value)')
parser.add_argument("-e", "--eps", dest="EnableEPS", help="Calculate theshold and result with EPS", default=False, action='store_true')
parser.add_argument("-i", "--ingest-time", dest="IngestTime", type=str, default='event.ingested', help='Ingesti time field or every time field that you want to use on query (default: %(default)s)')
parser.add_argument("-c", "--check-interval", dest="CheckInterval", type=str, default='5m', help='Check interval time format s, m, h, d (default: %(default)s)')
parser.add_argument("-wt", "--warning", dest="WarningThresold", type=int, default=0, help='Warning threshold number of events or EPS (if parameter enabled) (default: 0)')
parser.add_argument("-ct", "--critical", dest="CriticalThresold", type=int, default=0, help='Critical threshold number of events or EPS (if parameter enabled) (default: 0)')

# Read arguments from command line
args = parser.parse_args()

if args.version:
    print(__version__)
if args.verbose:
    logging.basicConfig(level=logging.DEBUG)
else:
    logging.basicConfig(level=logging.INFO)

if args.WarningThresold < 0 or args.CriticalThresold < 0:
    message = "UNKNOWN - Threshold cannot be a negative number."
    print(message)
    sys.exit(3)

# Set logger
logger = logging.getLogger()

SHOW_EPS = args.EnableEPS

tenant = args.TenantId
time_field = args.IngestTime
agent = args.AgentType

CHECK_INTERVAL = args.CheckInterval

# Building Elasticsearch request URL and filter
if agent == 'all':
    URL = "https://elasticsearch.neteyelocal:9200/auditbeat-*,winlogbeat-*,packetbeat-*,filebeat-*,metricbeat-*,logstash-*,logs-*,metrics-*/_count?ignore_unavailable=true"
    FILTER = '{ "bool": {  "should": [  {  "bool": {"should": [  {"match": {  "NETEYE.customer": "'+ tenant + '"}  }],"minimum_should_match": 1  }},{  "bool": {"should": [  {"match": {  "data_stream.namespace": "'+ tenant + '"}  }],"minimum_should_match": 1  }}  ],  "minimum_should_match": 1}  }'

elif agent == 'elastic_agent':
    URL = "https://elasticsearch.neteyelocal:9200/logs-*,metrics-*/_count?ignore_unavailable=true"
    FILTER='{  "bool": {"should": [  {"match": {  "data_stream.namespace": "'+ tenant + '"}  }],"minimum_should_match": 1  }}'

else:
    URL = "https://elasticsearch.neteyelocal:9200/" + agent + "-*/_count?ignore_unavailable=true"
    FILTER='{  "bool": {"should": [  {"match": {  "NETEYE.customer": "'+ tenant + '"}  }],"minimum_should_match": 1  }}'


if args.Filters:
    for f in args.Filters:
        filter, value = f[0].split('=',1)
        FILTER += ', { "bool": {  "should": [{ "match_phrase" : { "'+ filter + '" : "'+ value + '" } }], "minimum_should_match": 1}  }'


# Check if default ILM exist (api doesn't support wildcards)
JSON_PAYLOAD = '''{ "query": {
        "bool": {
            "filter": [
                {
                    "bool": {
                        "filter": [
                            ''' + FILTER + '''
                        ]
                    }
                },
                {
                    "range": {
                        "''' + time_field + '''": {
                            "gte": "now-''' + CHECK_INTERVAL + '''"
                        }
                    }
                }
            ]
        }
    }
}'''

payload_data = json.loads(JSON_PAYLOAD)
logging.debug(JSON_PAYLOAD)

try:
    r = requests.get(URL, headers=headers, data=json.dumps(payload_data), cert=(cert_path + cert_file,cert_path + key_file), verify=False)
except (ConnectionError, ReadTimeout) as e:
    ## Error on Elastic
    logging.warning("Elastic connection error")
    EXIT_CODE = UNKNOWN_CODE

if r.status_code == 200:
    #logging.info("The ILM policy named: '"+ lifecycle + "' already exists. \nPlease provide --override parameter if you want to clean all the configurations for this tenant.")
    logging.debug(r.content)
    JSON_RES = json.loads(r.content)
    TOTAL_EVENTS = JSON_RES['count']

    if SHOW_EPS == True:
        total_result = CalculateEPS (int(TOTAL_EVENTS), CHECK_INTERVAL)
    else:
        # Count Events
        total_result = TOTAL_EVENTS

    if total_result == 0 or total_result <= args.CriticalThresold:
        EXIT_CODE = CRITICAL_CODE
    elif total_result <= args.WarningThresold:
        EXIT_CODE = WARNING_CODE
    else:
        EXIT_CODE = OK_CODE

else:
    ## Error on Elastic
    EXIT_CODE = UNKNOWN_CODE

#################
# Icinga output #
#################

## OK
if EXIT_CODE == OK_CODE:
    message = "OK - " + str(TOTAL_EVENTS) + " events ingested in Elasticsearch in the last " + CHECK_INTERVAL
    if SHOW_EPS:
        message += " with a total of " + str(total_result) + " EPS\n"
    else:
        message += ".\n"

## WARNING
if EXIT_CODE == WARNING_CODE:
    message = "WARNING - The number of events ingested in Elasticsearch are "+ str(TOTAL_EVENTS) +" events, below the threshold of "
    if SHOW_EPS:
        message += str(args.WarningThresold) + " EPS in the last " + CHECK_INTERVAL + ". (" + str(total_result) + " E/s)\n"
    else:
        message += str(args.WarningThresold) + " events in the last " + CHECK_INTERVAL + ".\n"

## CRITICAL
if EXIT_CODE == CRITICAL_CODE:
    if TOTAL_EVENTS == 0:
        message = "CRITICAL - No events ingested in Elasticsearch in the last " + CHECK_INTERVAL + ".\n"
    else:
        message = "CRITICAL - The number of events ingested in Elasticsearch are "+ str(TOTAL_EVENTS) +" events, below the threshold of "
        if SHOW_EPS:
            message += str(args.CriticalThresold) + " EPS in the last " + CHECK_INTERVAL + ". (" + str(total_result) + " E/s)\n"
        else:
            message += str(args.CriticalThresold) + " events in the last " + CHECK_INTERVAL + ".\n"

## Common message
message += "Tenant: " + tenant + "<br>"
message += "Agent Type: " + agent + "<br>"
message += "Ingest Time: " + time_field + "<br>"
if args.Filters:
    message += "Filters: " + str(args.Filters) + "<br>"
# Perf data
if SHOW_EPS:
    message += "| 'TotalEvents'=" + str(TOTAL_EVENTS) + ";;;0; 'TotalEps'=" + str(total_result) + ";" + str(args.WarningThresold) + ";" + str(args.CriticalThresold) + ";0;"
else:
    message += "| 'TotalEvents'=" + str(TOTAL_EVENTS) + ";"+ str(args.WarningThresold) + ";" + str(args.CriticalThresold) + ";0;"


## UNKNOW (error on api)
if EXIT_CODE == UNKNOWN_CODE:
    message = "UNKNOWN - Elasticsearch API error.\nStatus Code: " + r.status_code + "<br>Reason: " + r.content

# Return message and exit code
print(message)
sys.exit(EXIT_CODE)