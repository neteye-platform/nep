#!/usr/bin/python3
####################################################
# Copyright Wuerth-Phoenix                         #
# This script can be distributed under GPL License #
# Author: CIMA                                     #
####################################################

# This script will help in removing duplicate EBP iterations on Elasticsearch
# https://www.elastic.co/guide/en/elasticsearch/reference/8.11/set-up-lifecycle-policy.html#switch-lifecycle-policies

import argparse
import logging
import json
from os import strerror
import requests
import sys
import re
import subprocess
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning) # Disable warning for Self Signed Certs

### GLOBAL VARS ###
headers = {"Content-Type": "application/json"}
cert_path = "/neteye/local/elasticsearch/conf/monitoring-certs/certs/"
cert_file = "NetEyeElasticCheck.crt.pem"
key_file = "private/NetEyeElasticCheck.key.pem"
URL="https://elasticsearch.neteyelocal:9200"

OK_CODE = 0
WARNING_CODE = 1
CRITICAL_CODE = 2
UNKNOWN_CODE = 3
### END GLOBAL VARS ###

### START FUNCTIONS ###
### END FUNCTIONS ###

### MAIN ####
__version__ = '0.0.1'
__version_date__ = '2024-03-05'


def main():
    # Arguments definition
    parser = argparse.ArgumentParser(description="Remove duplicate EBP iterations from Elasticsearch")
    parser.add_argument("-V", "--version", help="Show program version", action="store_true")
    parser.add_argument('-v', '--verbose', help="Enable verbose mode", action='store_true')
    parser.add_argument('--logging', help="Enable logging mode", action='store_true')
    parser.add_argument("-b", "--blockchain", dest="Blockchain", type=str, required=True, help='Blockchain to search iterations into the format <tenant>-<retention>-<tag>')

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

    ####### MAIN CODE #######

    blockchain = args.Blockchain

    ## Retrieve duplicated iterations from icingacli command and parse the result
    icingacli_command_result = subprocess.run(["icingacli", "monitoring", "list", "services", f"--service=EBP Verify Status - {blockchain}", "--format=json", "--columns=service_state,service_output"], stdout=subprocess.PIPE) # capture_output=True, text=True instead of subprocess.PIPE only works in python >= 3.7

    service = json.loads(icingacli_command_result.stdout)[0]
    if len(service) == 0:
        message = f"CRITICAL - The service 'EBP Verify Status - {blockchain}' does not exists. Create that service check first."
        logging.debug(message)
        print(message)
        sys.exit(CRITICAL_CODE)

    service_state = int(service["service_state"])
    if service_state == 0:
        message = f"OK - The Blockchain [{blockchain}] does not have duplicated iterations."
        logging.debug(message)
        print(message)
        sys.exit(OK_CODE)
    elif service_state == 3:
        message = f"UNKNOWN - The check 'EBP Verify Status - {blockchain}' is in UNKNOWN state. Please fix that check first."
        logging.debug(message)
        print(message)
        sys.exit(UNKNOWN_CODE)

    # Retrieve the array of duplicated iteration
    ITERATIONS = []
    try:
        ITERATIONS = re.findall(r'The blockchain contains duplicate logs, on iterations: \[(.*?)\]', service["service_output"])[0].split(', ')
    except Exception as ex:
        ITERATIONS = []

    if len(ITERATIONS) == 0:
        message = f"OK - The Blockchain [{blockchain}] does not have duplicated iterations."
        logging.debug(message)
        print(message)
        sys.exit(OK_CODE)

    ## For each iteration, retrieve the documents and delete all but the first
    docs_deleted = 0    # Initializing counter for metrics
    for e in ITERATIONS:
        payload = {
            "query": {
                "terms": {
                "ES_BLOCKCHAIN.iteration": [e]
                }
            },
            "_source": ["_id", "_index"],
            "size": 1000
        }

        # Retrieving the documents IDs and Indexes where they are located
        http_response = requests.post(f"{URL}/*-{blockchain}/_search",
                                      headers=headers,
                                      cert=(cert_path + cert_file,cert_path + key_file),
                                      verify=False,
                                      data = json.dumps(payload))
        if http_response.status_code != 200:
            message = f"WARNING - Elasticsearch is throwing an error.\n{http_response.text}"
            logging.error(message)
            print(message)
            sys.exit(WARNING_CODE)

        JSON_RES = json.loads(http_response.content)

        ## Deleting the documents for the same iteration
        for hit in JSON_RES['hits']['hits'][1:]:
            logging.debug(f"Checking and enabling writes on {hit['_index']}")
            # Retrieving index settings
            writes_request = requests.get(f"{URL}/{hit['_index']}/_settings",
                                        headers=headers,
                                        cert=(cert_path + cert_file,cert_path + key_file),
                                        verify=False)
            if writes_request.status_code != 200:
                message = f"WARNING - Elasticsearch is throwing an error.\n{http_response.text}"
                logging.error(message)
                print(message)
                sys.exit(WARNING_CODE)

            # Retrieve if index is blocked or not
            try:
                is_index_blocked = json.loads(writes_request.content)[hit['_index']]['settings']['index']['blocks']['write']
            except KeyError:
                is_index_blocked = None

            # If index writes are blocked then reopen index for rewrites
            if is_index_blocked:
                writes_request = requests.put(f"{URL}/{hit['_index']}/_settings",
                                            headers=headers,
                                            cert=(cert_path + cert_file,cert_path + key_file),
                                            verify=False,
                                            json={"index.blocks.write": False})
                if writes_request.status_code != 200:
                    message = f"WARNING - Elasticsearch is throwing an error.\n{http_response.text}"
                    logging.error(message)
                    print(message)
                    sys.exit(WARNING_CODE)

                logging.debug(f"Enabled writes for {hit['_index']}")

            # Delete corresponding document
            http_response = requests.delete(f"{URL}/{hit['_index']}/_doc/{hit['_id']}",
                                            headers=headers,
                                            cert=(cert_path + cert_file,cert_path + key_file),
                                            verify=False)
            if http_response.status_code != 200:
                message = f"CRITICAL - Elasticsearch returned an error. Procedure Aborted.\nThe index {[hit['_index']]} property 'index.blocks.write' was set to [{is_index_blocked}] and now is set to False. Please, change accordingly.\n{http_response.text}"
                logging.critical(message)
                print(message)
                sys.exit(CRITICAL_CODE)

            docs_deleted += 1


    if docs_deleted > 0:
        message = f"OK - {docs_deleted} documents deleted from blockchain {blockchain} | 'docs_deleted'={docs_deleted};;;0;"
        logging.debug(message)
        print(message)
        sys.exit(OK_CODE)


if __name__ == "__main__":
    main()