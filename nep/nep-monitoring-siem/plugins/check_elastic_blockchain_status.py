#!/usr/bin/python3.9
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
from datetime import datetime, timezone
from requests.exceptions import ReadTimeout, ConnectionError

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

### END FUNCTIONS ###

### MAIN ####
__version__ = '0.0.1'
__version_date__ = '2024-11-11'


# Arguments definition
parser = argparse.ArgumentParser(description="Check data receiving into Elasticsearch based on agent and filters")
parser.add_argument("-V", "--version", help="show program version", action="store_true")
parser.add_argument('-v', '--verbose', help="enable verbose mode", action='store_true')
parser.add_argument("-t", "--tenant", dest="TenantId", type=str, required=True, help='Tenant ID where search data (like namespace for ElasticAgent)')
parser.add_argument("-i", "--ingest-time", dest="IngestTime", type=str, default='event.ingested', help='Ingesti time field or every time field that you want to use on query (default: %(default)s)')
parser.add_argument("-H", "--host", dest="Hostname", type=str, required=True, help='Hostname FQDN to filter search')
parser.add_argument("-c", "--check-interval", dest="CheckInterval", type=str, default='180d', help='Check interval time format s, m, h, d (default: %(default)s)')
parser.add_argument("-w", "--warning", dest="WarningThresold", type=int, default=30, help='Warning threshold number of days without reach events (default: 30)')

# Read arguments from command line
args = parser.parse_args()

if args.version:
    print(__version__)
if args.verbose:
    logging.basicConfig(level=logging.DEBUG)
else:
    logging.basicConfig(level=logging.INFO)


# Set logger
logger = logging.getLogger()

host = args.Hostname
tenant = args.TenantId
time_field = args.IngestTime

CHECK_INTERVAL = args.CheckInterval

# Building Elasticsearch request URL and filter
URL = "https://elasticsearch.neteyelocal:9200/*-elproxysigned-"+ tenant + "-*/_search?ignore_unavailable=true"
FILTER = '{ "term": {  "NETEYE.hostname": "'+ host + '"} }'


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
    },
    "fields": [
        "''' + time_field + '''"
     ],
    "sort": [{
        "''' + time_field + '''": {
            "order": "desc"
            }
        }
    ],
    "size" : 1,
    "_source": false
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
    total_result = JSON_RES['hits']['total']['value']

    if total_result == 0:
        # no event found
        EXIT_CODE = CRITICAL_CODE
    else:
        # retrive date
        DATE_EVENT = JSON_RES['hits']["hits"][0]['fields'][time_field][0]
        logging.debug(DATE_EVENT)
        today = datetime.now(timezone.utc)
        difference_in_days = (today - datetime.fromisoformat(DATE_EVENT.replace('Z', '+00:00'))).days

        if difference_in_days >= args.WarningThresold:
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
    message = "OK - Last event from hostname '"+ host + "' saved into Blockchain is of: " + DATE_EVENT + ".\n"

## WARNING
if EXIT_CODE == WARNING_CODE:
    message = "WARNING - Last event from hostname '"+ host + "' saved into Blockchain is of: " + DATE_EVENT + ". This is more than thresold of " + str(args.WarningThresold) +  "d.\n"

## CRITICAL
if EXIT_CODE == CRITICAL_CODE:
    message = "CRITICAL - No events from hostname '"+ host + "' saved into Blockchain in the last " + CHECK_INTERVAL + ".\n"

## Common message
message += "Tenant: " + tenant + "<br>"
message += "Ingest Time: " + time_field + "<br>"

## UNKNOW (error on api)
if EXIT_CODE == UNKNOWN_CODE:
    message = "UNKNOWN - Elasticsearch API error.\nStatus Code: " + r.status_code + "<br>Reason: " + r.content

# Return message and exit code
print(message)
sys.exit(EXIT_CODE)