#!/usr/bin/python3
####################################################
# Copyright Wuerth-Phoenix                         #
# This script can be distributed under GPL License #
# Author: ALEN & SOC Team                          #
####################################################

# This script will help in configuring a customer items on Elastic Infrastructure
# It support also deletions of customer spaces.

import argparse, requests, sys, copy
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

tornado_url = "http://neteye.neteyelocal:8080/event/"

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

def SearchOnElastic():
    JSON_PAYLOAD = '''
    {
    "query": {
        "bool": {
        "must": [
            {
            "range": {
                "''' + time_field + '''": {
                "gte": "now-''' + CHECK_INTERVAL + '''"
                }
            }
            }  ''' + TENANT_FILTER + '''
        ],
        "must_not": [
            {
            "term": {
                "tags": "neteye_object_not_found"
            }
            }  ''' + DATASET_FILTER + '''
        ]
        }
    },
        "aggs": {
            "results": {
            "multi_terms": {
                "terms": [
                    ''' + TERMS + '''
                    ],
                    "size": ''' + str(SIZE) + '''
                }

            }
        },
        "size": 0,
        "_source": false
    }'''

    logging.debug(JSON_PAYLOAD)
    payload_data = json.loads(JSON_PAYLOAD)

    try:
        r = requests.get(URL, headers=headers, data=json.dumps(payload_data), cert=(cert_path + cert_file,cert_path + key_file), verify=False)
    except (ConnectionError, ReadTimeout) as e:
        ## Error on Elastic
        logging.warning("Elastic connection error")
        return UNKNOWN_CODE, []

    if r.status_code == 200:
        logging.debug(r.content)
        JSON_RES = json.loads(r.content)

        ## Check if there are results
        if JSON_RES == {}:
            return WARNING_CODE , []
        else:
            return OK_CODE, JSON_RES['aggregations']['results']['buckets']
    else:
        ## Error on Elastic
        return UNKNOWN_CODE, []
### END FUNCTIONS ###

### MAIN ####
__version__ = '0.1.2'
__version_date__ = '2025-05-20'


# Arguments definition
parser = argparse.ArgumentParser(description="Check data receiving into Elasticsearch based on agent and filters")
parser.add_argument("-V", "--version", help="show program version", action="store_true")
parser.add_argument('-v', '--verbose', help="enable verbose mode", action='store_true')
parser.add_argument("-t", "--tenant", dest="TenantId", type=str, help='Tenant ID where search data (like namespace for ElasticAgent)')
parser.add_argument("-a", "--agent", dest="AgentType", type=str.lower, default='elastic_agent', choices=['beats', 'elastic_agent', 'logstash'], help='Choose agent type for check (default: %(default)s)')
parser.add_argument("-i", "--ingest-time", dest="IngestTime", type=str, default='event.ingested', help='Ingesti time field or every time field that you want to use on query (default: %(default)s)')
parser.add_argument("-e", "--exclude-dataset", dest="ExcludeDataset", type=str, action='append', help='Dataset name to be excluded from check, this param can be use multiple times')
parser.add_argument("-c", "--check-interval", dest="CheckInterval", type=str, default='5m', help='Check interval time format s, m, h, d (default: %(default)s)')
parser.add_argument("-w", "--webhook", dest="Webhook", type=str, required=True, help='Webhook endpoint enabled in Tornado')
parser.add_argument("-s", "--secret", dest="Secret", type=str, required=True, help='Webhook endpoint token secret in Tornado')
parser.add_argument("-m", "--metrics", dest="Metrics", action='store_true', help='Enable also Elasticserach Metrics indices for serach')
parser.add_argument('--logging', help="enable logging mode", action='store_true')

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

if not args.logging:
    logger.disabled = True

# if tenant is provided otherwise check all
if args.TenantId:
    tenant = args.TenantId

TENANT_FILTER = ''
DATASET_FILTER = ''

if args.ExcludeDataset:
    logging.debug(args.ExcludeDataset)
    for dataset in args.ExcludeDataset:
        DATASET_FILTER += ', { "term": { "event.dataset" : "'+ dataset + '" } }'

webhook = args.Webhook
secret = args.Secret
time_field = args.IngestTime
agent = args.AgentType
CHECK_INTERVAL = args.CheckInterval
SIZE = 50000
TOTAL_EVENTS = 0
webhook_sent = 0
webhook_error = 0

# Building Elasticsearch request URL and filter
if agent == 'elastic_agent':
    if args.Metrics:
        URL = "https://elasticsearch.neteyelocal:9200/logs-*,metrics-*,-logs-endpoint*,-logs-apm*/_search?filter_path=aggregations.results.buckets.key_as_string,aggregations.results.buckets.doc_count"
    else:
        URL = "https://elasticsearch.neteyelocal:9200/logs-*,-logs-endpoint*,-logs-apm*/_search?filter_path=aggregations.results.buckets.key_as_string,aggregations.results.buckets.doc_count"
    TERMS='{ "field": "data_stream.namespace" }, { "field": "NETEYE.hostname" }, { "field": "agent.type", "missing": "none" },{ "field": "data_stream.dataset" },{ "field": "input.type", "missing": "none" }'
    TENANT_FILTER = ', { "term": { "data_stream.namespace": "' + tenant + '" } }'

elif agent == 'beats':
    if args.Metrics:
        URL = "https://elasticsearch.neteyelocal:9200/auditbeat-*,winlogbeat-*,packetbeat-*,filebeat-*,metricbeat-*/_search?filter_path=aggregations.results.buckets.key_as_string,aggregations.results.buckets.doc_count"
    else:
        URL = "https://elasticsearch.neteyelocal:9200/auditbeat-*,winlogbeat-*,packetbeat-*,filebeat-*/_search?filter_path=aggregations.results.buckets.key_as_string,aggregations.results.buckets.doc_count"
    TERMS='{ "field": "NETEYE.customer" }, { "field": "NETEYE.hostname" }, { "field": "agent.type" },{ "field": "event.dataset" }'
    TENANT_FILTER = ', { "term": { "NETEYE.customer": "' + tenant + '" } }'

elif agent == 'logstash':
    URL = "https://elasticsearch.neteyelocal:9200/logstash-*/_search?filter_path=aggregations.results.buckets.key_as_string,aggregations.results.buckets.doc_count"
    TERMS='{ "field": "NETEYE.customer" }, { "field": "NETEYE.hostname" }, { "field": "agent.type" },{ "field": "event.dataset" }'
    TENANT_FILTER = ', { "term": { "NETEYE.customer": "' + tenant + '" } }'

result, raw_events = SearchOnElastic()
logging.info("Search on Elastic returns: " + str(result))

if result == 0:
    EXIT_CODE = copy.deepcopy(OK_CODE)
    ## Iterate over results and send Tornado webhooks
    for event in raw_events:
        # Sample:
        #   {
        #       "key_as_string" : "103956|pbzdc01.wp.lan|packetbeat|dns|udp",
        #       "doc_count" : 80484
        #   },
        #   {
        #       "key_as_string" : "103956|pbzdc01.wp.lan|packetbeat|dns|none",
        #       "doc_count" : 80484
        #   }
        result = event['key_as_string'].split('|')
        tot_docs = event['doc_count']
        TOTAL_EVENTS += tot_docs
        ## make paylod for tornado
        payload_data = {}
        payload_data['tenant'] = result[0]
        payload_data['hostname'] = result[1]
        payload_data['agent'] = result[2]
        payload_data['dataset'] = result[3]
        ## Convert agent.type
        if agent == 'elastic_agent':
            payload_data['type'] = "elastic_agent"
            if result[4] in ["tcp", "udp", "syslog"]:
                payload_data['type'] = "syslog"
            if result[4] in [ "http_endpoint" ]:
                payload_data['type'] = "http_endpoint"
            if result[4] in ["cel", "httpjson", "o365audit", "azure-eventhub"]:
                payload_data['type'] = "cloud_api"
        else:
            payload_data['type'] = agent
        payload_data['docs'] = tot_docs

        logging.debug(payload_data)
        ## Post to Tornado
        r = requests.post(tornado_url + webhook + "?token=" + secret, data=json.dumps(payload_data), headers=headers, verify=False)
        if r.status_code == 200:
            logging.debug('Ok sent webhook')
            webhook_sent += 1
        else:
            ## Error on send webhook
            webhook_error += 1
            EXIT_CODE = copy.deepcopy(CRITICAL_CODE)
            logging.debug("Webhook error. Return code: " + str(r.status_code) + ", content: " + str(r.content))

    # Endpoint (Defend) and APM logs
    if agent == 'elastic_agent':
        URL = "https://elasticsearch.neteyelocal:9200/logs-endpoint*,logs-apm*/_search?filter_path=aggregations.results.buckets.key_as_string,aggregations.results.buckets.doc_count"

        result, raw_events = SearchOnElastic()
        logging.info("Search on Elastic returns: " + str(result))
        if result == 0:
            payload_data = {}
            ## Iterate over results and send only one Tornado webhooks for host
            for event in raw_events:
                # Sample:
                #   {
                #       "key_as_string" : "103956|pbzdc01.wp.lan|endpoint|endpoint.events.file|none",
                #       "doc_count" : 80484
                #   },
                #   {
                #       "key_as_string" : "103956|pbzdc01.wp.lan|none|apm.app.d365|none",
                #       "doc_count" : 20
                #   }
                result = event['key_as_string'].split('|')
                tot_docs = event['doc_count']
                hostname = result[1]
                dateset = result[3]
                if hostname not in payload_data:
                    payload_data[hostname] = {}
                    payload_data[hostname]['docs'] = 0
                    payload_data[hostname]['tenant'] = result[0]
                    payload_data[hostname]['hostname'] = result[1]
                    payload_data[hostname]['agent'] = result[2]
                    payload_data[hostname]['type'] = "elastic_agent"
                    payload_data[hostname]['dateset'] = {}
                payload_data[hostname]['docs'] += tot_docs
                payload_data[hostname]['dateset'][dateset] = tot_docs
                TOTAL_EVENTS += tot_docs

            logging.debug(payload_data)
            ## Post to Tornado
            for key, value in payload_data.items():
                logging.debug(value)
                r = requests.post(tornado_url + webhook + "?token=" + secret, data=json.dumps(value), headers=headers, verify=False)
                if r.status_code == 200:
                    logging.debug('Ok sent webhook')
                    webhook_sent += 1
                else:
                    ## Error on send webhook
                    webhook_error += 1
                    EXIT_CODE = CRITICAL_CODE
                    logging.debug("Webhook error. Return code: " + str(r.status_code) + ", content: " + str(r.content))
        elif result == 1:
            logging.info("No endpoint or apm events founded.")
        else:
            EXIT_CODE = copy.deepcopy(result)
else:
    EXIT_CODE = copy.deepcopy(result)
#################
# Icinga output #
#################

## OK
if EXIT_CODE == OK_CODE:
    message = "OK - " + str(TOTAL_EVENTS) + " events found on Elasticsearch in the last " + CHECK_INTERVAL + ". " + str(webhook_sent) + " webhooks sent correctly to Tornado.<br>"

## WARNING
if EXIT_CODE == WARNING_CODE:
    message = "WARNING - No events found in Elasticsearch in the last " + CHECK_INTERVAL + ".<br>"

## CRITICAL
if EXIT_CODE == CRITICAL_CODE:
    message = "CRITICAL - Some webhooks to Tornado are not sent correctly! "+ str(TOTAL_EVENTS) +" events found on Elasticsearch in the last " + CHECK_INTERVAL + ".<br>"

## Common message
#if tenant:
#    message += "Tenant: " + tenant + "<br>"
message += "Agent Type: " + agent + "<br>"
message += "Ingest Time: " + time_field + "<br>"
message += "Bucket Size: " + str(SIZE) + "<br>"


# Perf data
message += "| 'TotalEvents'=" + str(TOTAL_EVENTS) + ";;;0; 'TotalWebhooks'=" + str(webhook_sent) + ";;;0; 'ErrorWebhooks'=" + str(webhook_error) + ";;;0;"


## UNKNOW (error on api)
if EXIT_CODE == UNKNOWN_CODE:
    message = "UNKNOWN - Elasticsearch API error.<br>Status Code: " + r.status_code + "<br>Reason: " + r.content

# Return message and exit code
print(message)
sys.exit(EXIT_CODE)