#!/usr/bin/python3
import os
import sys
import json
import requests
import argparse
import logging
from time import sleep
from jsonschema import Draft7Validator, validators

ROOT = os.path.abspath(os.path.dirname(__file__))

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SETTINGS_SCHEMA = {
    "type":"object",
    "properties":{
        "method": {
            "enum": ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"],
            "default":"POST"
        },
        "url":{"type":"string"},
        "user":{"type":"string"},
        "pass":{"type":"string"},
        "headers":{
            "type":"object",
            "patternProperties":{
                ".+":{"type":"string"}
            }
        },
        "cookies":{
            "type":"object",
            "patternProperties":{
                ".+":{"type":"string"}
            }
        },
        "timeout":{
            "type":"number",
            "default":60.0,
            "minimum":0.0
        },
        "verify":{"type":"boolean"},
        "cert":{
            "oneOf":[
                {"type":"string"},
                {"const":None},
            ],
        },
        "retries":{
            "type":"integer",
            "$comment":"how many retries before moving on to the next endpoint, -1 is infinite retries",
            "default":5,
            "minimum": -1
        },
        "retries_delay":{
            "type":"number",
            "$comment":"how many seconds to wait between each retry",
            "default":0.5,
            "minimum": 0.0
        }
    },
    "required": ["url"],
    "additionalProperties": False
}

def extend_with_default(validator_class):
    validate_properties = validator_class.VALIDATORS["properties"]

    def set_defaults(validator, properties, instance, schema):
        for property, subschema in properties.items():
            if "default" in subschema:
                instance.setdefault(property, subschema["default"])

        for error in validate_properties(
            validator, properties, instance, schema,
        ):
            yield error

    return validators.extend(
        validator_class, {"properties" : set_defaults},
    )

def get_settings(path):
    if not os.path.exists(path) or not os.path.isfile(path):
        logger.error("The given settings path doesn't exit. '{}'".format(path))
        sys.exit(1)

    with open(path, "r") as f:
        settings = json.load(f)
    # THIS SETS THE DEFAULT IN PLACE
    extend_with_default(Draft7Validator)(SETTINGS_SCHEMA).validate(settings)
    return settings

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--settings',
        type=str,
        default=os.path.join(ROOT, "nx-notification-servicenow.json"),
        help='The path to the endpoint settings. Default: %(default)s'
    )
    parser.add_argument(
        '--service',
        type=str,
        help='Is the name of the service / CI in the SN that faulted'
    )
    parser.add_argument(
        '--message',
        type=str,
        help='Is the fault\'s info message'
    )
    parser.add_argument(
        '--type',
        type=str,
        choices=["degradation", "outage", "planned", "ok"],
        help='is the type of fault'
    )
    parser.add_argument(
        '--start',
        type=str,
        help=''
    )
    args = parser.parse_args()

    settings = get_settings(args.settings)

    payload = {
        "u_ci_service":args.service,
        "u_message":args.message,
        "u_type":args.type,
        "u_start":args.start,
    }

    request_args = {
        key:settings[key]
        for key in [
            "method", "url", "headers", "cookies", "timeout",
            "verify", "cert",
        ]
        if key in settings
    }

    if "user" in settings and "pass" in settings:
        request_args["auth"] = (settings["user"], settings["pass"])

    request_args["json"] = payload

    retires = settings["retries"]
    while retires != 0:
        try:
            r = requests.request(**request_args)
            logger.info("Got status code '%s'", r.status_code)
            r.raise_for_status()
            logger.info("Got result: '%s'", r.text)

            return r.text
        except Exception as e:
            logger.error("Got exception: %s", e)

        sleep(settings["retries_delay"])
        retires -= 1

    logger.critical("Could not")
    sys.exit(1)


if __name__ == "__main__":
    main()
