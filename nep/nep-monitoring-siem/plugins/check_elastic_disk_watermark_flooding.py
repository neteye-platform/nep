#!/usr/bin/python3.9

####################################################
# Copyright Wuerth-Phoenix                         #
# This script can be distributed under GPL License #
# Author: CIMA                                     #
####################################################

# This script will retrieve information about Elasticsearch Disk Flood Watermark

import requests
import argparse
import re
import sys
import os

# Disable warning for Self Signed Certs
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

headers = {"Content-Type": "application/json"}
cert_path = "/neteye/local/elasticsearch/conf/monitoring-certs/certs/"
cert_file = "NetEyeElasticCheck.crt.pem"
key_file = "private/NetEyeElasticCheck.key.pem"
elasticsearch_url = "https://elasticsearch.neteyelocal:9200"

OK_CODE = 0
WARNING_CODE = 1
CRITICAL_CODE = 2
UNKNOWN_CODE = 3

__version__ = '0.1.1'
__version_date__ = '2024-12-03'


def get_flood_stage():
    try:
        response = requests.get(f"{elasticsearch_url}/_cluster/settings?include_defaults=true",
                                cert=(f"{cert_path}{cert_file}", f"{cert_path}{key_file}"),
                                verify=False,
                                timeout=120)
        response.raise_for_status()
        settings = response.json()

        # Search the flood_stage in persistent, transient or default
        flood_stage = (
          settings.get('persistent', {}).get('cluster', {}).get('routing', {}).get('allocation', {}).get('disk', {}).get('watermark', {}).get('flood_stage') or
          settings.get('transient', {}).get('cluster', {}).get('routing', {}).get('allocation', {}).get('disk', {}).get('watermark', {}).get('flood_stage') or
          settings.get('defaults', {}).get('cluster', {}).get('routing', {}).get('allocation', {}).get('disk', {}).get('watermark', {}).get('flood_stage')
        )

        if flood_stage is None:
            raise ValueError("Cannot get Flood stage value from cluster settings.")

        # Convert flood_stage in byte
        return flood_stage

    except requests.exceptions.RequestException as e:
        print(f"Error while retrieving flood_stage from Elasticsearch: {e}")
        sys.exit(1)


# Main function for monitoring
def monitor_disk(path, warning_multiplier, critical_multiplier):
    try:
        # Get Free Space
        statvfs = os.statvfs(path)
        free_space = statvfs.f_bavail * statvfs.f_frsize
        total_space = statvfs.f_blocks * statvfs.f_frsize
        free_space_percentage = free_space / total_space
        used_space = total_space - free_space

        flood_stage_string = get_flood_stage()

        if flood_stage_string.endswith("%"):
            # If flood_stage is a percentage, convert it to bytes depending on total space
            flood_stage_percentage = float(flood_stage_string[:-1])
            # Take the equivalent of the actual flood stage in bytes (the space that remains free on the disk at flood_stage percentage)
            flood_stage = ((100 - flood_stage_percentage) / 100) * total_space
        else:
            # If flood_stage is a size in bytes, convert it to bytes
            flood_stage = parse_size(flood_stage_string)

    except Exception as e:
        print(f"UNKNOWN - Error: {e}")
        sys.exit(UNKNOWN_CODE)

    # Verify thresholds
    if free_space < critical_multiplier * flood_stage:
        print(f"CRITICAL - Free space is below {critical_multiplier}x flood_stage threshold ({free_space_percentage*100:.2f}% free - {format_size(free_space)}) - (Used: {format_size(used_space)}) - (flood_stage: {flood_stage_string})")
        sys.exit(CRITICAL_CODE)
    elif free_space < warning_multiplier * flood_stage:
        print(f"WARNING - Free space is below {warning_multiplier}x flood_stage threshold ({free_space_percentage*100:.2f}% free - {format_size(free_space)}) - (Used: {format_size(used_space)}) - (flood_stage: {flood_stage_string})")
        sys.exit(WARNING_CODE)
    else:
        print(f"OK - Free space is sufficient ({free_space_percentage*100:.2f}% free - {format_size(free_space)}) - (Used: {format_size(used_space)}) - (flood_stage: {flood_stage_string})")
        sys.exit(OK_CODE)

# Function to convert flood_stage from string to bytes
def parse_size(size_str):
    size_str = size_str.lower().strip()
    size_mapping = {
        'b': 1,
        'kb': 1024,
        'mb': 1024**2,
        'gb': 1024**3,
        'tb': 1024**4,
        'g': 1024**3,  # Manage 'g' without 'b'
        'm': 1024**2,  # Manage 'm' without 'b'
        'k': 1024      # Manage 'k' without 'b'
    }

    # Use regex to extract numerical value and unit
    match = re.match(r"([\d.]+)([a-z]*)", size_str)
    if match:
        value = float(match.group(1))
        unit = match.group(2)
        return value * size_mapping.get(unit, 1)  # Default to byte if not specified

    raise ValueError(f"Invalid size format: {size_str}")

# Function to format byte sizes in human readable format
def format_size(byte_size):
    if byte_size < 1024:
        return f"{byte_size} B"
    elif byte_size < 1024**2:
        return f"{byte_size / 1024:.2f} KB"
    elif byte_size < 1024**3:
        return f"{byte_size / 1024**2:.2f} MB"
    elif byte_size < 1024**4:
        return f"{byte_size / 1024**3:.2f} GB"
    else:
        return f"{byte_size / 1024**4:.2f} TB"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Monitor Elasticsearch disk space against flood_stage threshold.')
    parser.add_argument("-V", "--version", help="Show program version", action="store_true")
    parser.add_argument('--path', type=str, required=True, help='Path to the Elasticsearch data disk (Usually /neteye/local/elasticsearch/data)')
    parser.add_argument('--warning-multiplier', type=float, default=2.0, help='Multiplier for warning threshold (default: 2.0)')
    parser.add_argument('--critical-multiplier', type=float, default=1.5, help='Multiplier for critical threshold (default: 1.5)')

    args = parser.parse_args()

    if args.version:
        print(__version__)

    monitor_disk(args.path, args.warning_multiplier, args.critical_multiplier)
