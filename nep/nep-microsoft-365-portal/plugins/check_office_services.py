#!/usr/bin/python3
import argparse
import sys

import requests
from requests.structures import CaseInsensitiveDict
import xmltodict

####################### Additional steps #################################################
# dnf install python3-xmltodict -y --enablerepo=epel                                     #
##########################################################################################

# Define MACROS
OK              = 0
WARNING         = 1
CRITICAL        = 2
UNKNOWN         = 3
OK_LABEL        = "[OK]"
WARNING_LABEL   = "[WARNING]"
CRITICAL_LABEL  = "[CRITICAL]"
UNKNOWN_LABEL   = "[UNKNOWN]"

# Main functions for parsing URL
def get_service_status(URL, mode, debug):

    URL_H='https://portal.office.com/servicestatus'

    # Define variables fro logic
    service_counter=0
    service_ok_counter=0
    service_list=""

    # URL = "https://portal.office.com/api/servicestatus/index"
    headers = CaseInsensitiveDict()
    headers["Accept"] = "application/xml"
    response = requests.get(URL,  headers=headers)
    if response.status_code != 200:
        print ("UNKNOWN - Not reachable <a href={} target=\"_blank\">Office Portal</a>".format( URL_H))
        sys.exit(UNKNOWN)

    #print(response.content)
    data = xmltodict.parse(response.text)

    # Loop over discoverd elements
    if data is not None:
        for d in data['IndexModel']['Services']['Service']:

                exit_label=CRITICAL_LABEL
                exit_status="DOWN"
                service_name=d['Name']
                service_status=d['IsUp']
                if mode=='all':
                    service_counter+=1
                    if service_status == 'true':
                        service_ok_counter+=1
                        exit_label=OK_LABEL
                        exit_status="UP"
                    service_list+="{} : {} {}\n".format(exit_label, service_name, exit_status)

                elif mode == service_name:
                    service_counter+=1
                    if service_status == 'true':
                        service_ok_counter+=1

    else:
        print ("UNKNOWN - Service Status of <a href={} target=\"_blank\">Office Portal</a>".format( URL_H))
        sys.exit(UNKNOWN)
    if  service_counter>0:
        if mode == "all" and service_counter==service_ok_counter:
            print ("{} - Service Status of <a href={} target=\"_blank\">Office Portal</a>\n{}".format(OK_LABEL,URL_H,service_list))
            sys.exit(OK)
        elif mode!= "all" and service_ok_counter==1:
            print ("{} - {} service is healthy in <a href={} target=\"_blank\">Office Portal</a>".format(OK_LABEL,mode,URL_H))
            sys.exit(OK)
        else:
            if mode == "all":
                print ("{} - Service Status of <a href={} target=\"_blank\">Office Portal</a>\n{}".format(CRITICAL_LABEL, URL_H,service_list))
                sys.exit(CRITICAL)
            else:
                print ("{} - {} service is NOT healthy in <a href={} target=\"_blank\">Office Portal</a>".format(CRITICAL_LABEL,mode,URL_H))
                sys.exit(CRITICAL)

    else:
        print ("{} - No Services found on <a href={} target=\"_blank\">Office Portal</a>\n".format(WARNING_LABEL,URL))
        sys.exit(WARNING)


# Ready for parametrization
def main():
    DEBUG = False
    # Parse arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--portal", help="Portal URL i.e. https://portal.office.com/api/servicestatus/index", type=str)
    parser.add_argument("-m", "--mode",   help="Serice Mode: all, Oulook.com, OneDrive", type=str)
    parser.add_argument("-v", "--verbose", help="Enable verbose", action='store_true')

    try:
        args = parser.parse_args()
        if args.verbose is not None and args.verbose == 'true':
            DEBUG = True
        if args.portal == None:
            print ("Warning: missing portal URL (i.e. https://portal.office.com/api/servicestatus/index)")
            sys.exit(WARNING)
        if args.mode == None:
            print ("Warning: service mode parameter (i.e. all, Oulook.com, OneDrive)")
            sys.exit(WARNING)
    except TypeError as e:
        print ("[WARNING] : {}".format(e))
        sys.exit(WARNING)
    get_service_status(args.portal,args.mode,DEBUG)


if __name__ == '__main__':
    main()