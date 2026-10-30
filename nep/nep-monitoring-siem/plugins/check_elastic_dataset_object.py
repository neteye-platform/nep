#!/usr/bin/python3
####################################################
# Copyright Wuerth-Phoenix                         #
# This script can be distributed under GPL License #
# Author: ALEN                                     #
####################################################

import requests, urllib3
import sys, re
import argparse
import logging
from requests.auth import HTTPBasicAuth

# Disable warnings for self-signed certs for Python >= 2.16.0
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

__version__ = '0.0.2'
__version_date__ = '2024-09-25'

# Setting up the argument parser
parser = argparse.ArgumentParser(description='Check datasets for a specified host.')
parser.add_argument("-V", "--version", help="show program version", action="store_true")
parser.add_argument('-v', '--verbose', help="enable verbose mode", action='store_true')
parser.add_argument('--host', required=True, type=str, help='The host to check datasets for.')
parser.add_argument('--logging', help="enable logging mode", action='store_true')

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

# Use the host argument from command line
host = args.host

# Constants
OK_CODE = 0
WARNING_CODE = 1
CRITICAL_CODE = 2
UNKNOWN_CODE = 3

ACCOUNT_USR="elastic-blockchain-proxy"
USR_CONFIG_FILE=f"/neteye/shared/icinga2/conf/icinga2/conf.d/{ACCOUNT_USR}-user.conf"
# Leggi il contenuto del file
with open(USR_CONFIG_FILE, 'r') as file:
    file_content = file.read()
# Utilizza una regex per trovare il valore della password
match = re.search(r'password\s*=\s*"([^"]+)"', file_content)
if match:
    password = match.group(1)
else:
    print("Not able to retrive Icinga password.")
    sys.exit(UNKNOWN_CODE)

URL = "https://icinga2-master.neteyelocal:5665/v1/"
AUTH = HTTPBasicAuth(ACCOUNT_USR, password)
headers = {"Content-Type": "application/json"}



datasets_perimeter = []
datasets_service = []

# GET HOSTS
http_response = requests.get(URL + "/objects/hosts/" + host, headers=headers, auth=AUTH, verify=False)
if http_response.status_code == 200:
    logging.info("Retrive hosts datasets...")
    logging.debug(http_response.json())
else:
    message = "UNKNOWN - error on Icinga API"
    logging.error(message)
    print(message)
    sys.exit(UNKNOWN_CODE)

output_hosts = http_response.json()

# GET SERVICES
data = {
    "type": "Service",
    "filter": f"host.name==\"{host}\" && match(\"Elastic Ingest Status*\",service.name)",
    "attrs": ["name"]
}
http_response = requests.get(URL + "/objects/services?", headers=headers, auth=AUTH, json=data, verify=False)

if http_response.status_code == 200:
    logging.info("Retrive services datasets...")
    logging.debug(http_response.json())
else:
    message = "UNKNOWN - error on Icinga API"
    logging.error(message)
    print(message)
    sys.exit(UNKNOWN_CODE)

output_services = http_response.json()

# Manage string variables
for attr in [ 'logmanager_log_dataset_http_endpoint', 'logmanager_log_dataset_syslog' ]:
    if attr in output_hosts['results'][0]['attrs']['vars']:
        datasets_perimeter.append(output_hosts['results'][0]['attrs']['vars'][attr])
# Manage array variables
for attr in [ 'logmanager_log_dataset_cloud_api','logmanager_log_dataset_elastic_agent' ]:
    if attr in output_hosts['results'][0]['attrs']['vars']:
        datasets_perimeter += output_hosts['results'][0]['attrs']['vars'][attr]

logging.debug(datasets_perimeter)

for service in output_services['results']:
    logging.debug("Processing service name: " + service['name'])
    datasets_service.append(service['name'].split(' - ')[1].split(' ')[0])

logging.debug(datasets_service)
# Calculate differences
less = list(set(datasets_perimeter) - set(datasets_service))
more = list(set(datasets_service) - set(datasets_perimeter))

# Prepare performance data
num_perimeter = len(datasets_perimeter)
num_service = len(datasets_service)
num_less = len(less)
num_more = len(more)

# Determine the status
if len(less) > 0 or len(more) > 0:
    # If there are differences, return CRITICAL
    message="CRITICAL - Datasets mismatch\n"

    if len(more) > 0:
        message+=f"More: {', '.join(more)}<br>"

    if len(less) > 0:
        message+=f"Less: {', '.join(less)}<br>"

    # Print performance data
    message+=f"| datasets_perimeter={num_perimeter};;;0; datasets_service={num_service};;;0; datasets_more={num_more};;;0; datasets_less={num_less};;;0;"
    print(message)
    sys.exit(CRITICAL_CODE)  # Icinga CRITICAL exit code
else:
    # If everything matches, return OK
    message="OK - Datasets match."
    # Print performance data
    message+=f"| datasets_perimeter={num_perimeter};;;0; datasets_service={num_service};;;0; datasets_more=0;;;0; datasets_less=0;;;0;"
    print(message)
    sys.exit(OK_CODE)  # Icinga OK exit code
