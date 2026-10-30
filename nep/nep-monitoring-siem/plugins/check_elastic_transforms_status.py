#!/usr/bin/python3
####################################################
# Copyright Wuerth-Phoenix                         #
# This script can be distributed under GPL License #
# Author: CIMA                                     #
####################################################

# This script will retrieve information about Elasticsearch Transforms from Elastic and send each transform status to a Tornado Webhook

import argparse
import logging
import json
import requests
import sys

# Disable warning for Self Signed Certs
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

headers = {"Content-Type": "application/json"}
cert_path = "/neteye/local/elasticsearch/conf/monitoring-certs/certs/"
cert_file = "NetEyeElasticCheck.crt.pem"
key_file = "private/NetEyeElasticCheck.key.pem"

elasticsearch_url = "https://elasticsearch.neteyelocal:9200"
tornado_url = "http://httpd.neteyelocal:8080/event/"

OK_CODE = 0
WARNING_CODE = 1
CRITICAL_CODE = 2
UNKNOWN_CODE = 3

# region Custom Functions
    # Empty
# endregion

### MAIN ####
__version__ = '0.1.1'
__version_date__ = '2024-10-04'

# Arguments definition
parser = argparse.ArgumentParser(description="Check Elasticsearch Transforms status and send webhooks to Tornado")
parser.add_argument("-V", "--version", help="Show program version", action="store_true")
parser.add_argument('-v', '--verbose', help="Enable verbose mode", action='store_true')
parser.add_argument("-c", "--check-interval", dest="CheckInterval", type=str, default='5m', help='Check interval time format s, m, h, d (default: %(default)s)')
# NOTE - Default webhook to be created nx_elastic_transforms
parser.add_argument("-w", "--webhook", dest="Webhook", type=str, required=True, help='Webhook endpoint enabled in Tornado')
parser.add_argument("-s", "--secret", dest="Secret", type=str, required=True, help='Webhook endpoint token secret in Tornado')

# Read arguments from command line
args = parser.parse_args()

if args.version:
    print(__version__)
if args.verbose:
    logging.basicConfig(level=logging.DEBUG)
else:
    logging.basicConfig(level=logging.INFO)

# Set parameters
logger = logging.getLogger()
webhook = args.Webhook
secret = args.Secret
CHECK_INTERVAL = args.CheckInterval
TOT_WEBHOOKS = 0
FROM = 0
SIZE = 100
message = ""

transforms = []

try:
    # This allows to perform a batch operation and retrieve all transforms since default size allowed is 100
    while True:
        response = requests.get(f"{elasticsearch_url}/_transform/_stats?size={SIZE}&from={FROM}",
                                cert=(f"{cert_path}{cert_file}", f"{cert_path}{key_file}"),
                                verify=False,
                                timeout=120)

        if response.status_code != 200:
            print("UNKNOWN - Error while connecting to Elasticsearch")
            sys.exit(UNKNOWN_CODE)

        logging.debug("Connection succeeded")

        # Parse response
        batch_transforms = response.json().get('transforms', [])
        # If no more results, break the loop
        if not batch_transforms:
            break

        # Add current batch to the main transforms list
        transforms.extend(batch_transforms)

        # Update pagination index
        FROM += SIZE

    if not transforms:
        print("UNKNOWN - Error while querying Elasticsearch, no Transform has been returned")
        sys.exit(UNKNOWN_CODE)

    for t in transforms:
        # Send data to Tornado
        request = requests.post(f"{tornado_url}{webhook}?token={secret}", data=json.dumps(t), headers=headers, verify=False)
        if request.status_code == 200:
            logging.debug(f"Webhook for {t['id']} sent to Tornado")
            TOT_WEBHOOKS += 1
        else:
            logging.debug(f"Error: Failed sending event to Tornado webhook for {t['id']}. Status Code: {request.status_code}.\n{request.content}")
            print(f"CRITICAL - Tornado webhook error. Status Code: {request.status_code}.<br>{request.content}")
            sys.exit(CRITICAL_CODE)


    message = f"OK - {str(TOT_WEBHOOKS)} webhooks have been sent to Tornado| 'TotalWebhooks'={str(TOT_WEBHOOKS)};;;0;"
    print(message)
    sys.exit(OK_CODE)
except Exception as e:
    logging.debug(f"Error: An error occurred while performing operation on Elasticsearch:<br>{e}")
    print(f"CRITICAL - Elasticsearch API Error: {e}")
    sys.exit(CRITICAL_CODE)
