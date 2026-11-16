#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################

# Old packages shihpped configuration file containing personal info.
# If this file has not been changed, it will be removev without asking.

function remove_alyvix_httpd_proxy() {
    FILE_TO_REMOVE=/etc/httpd/conf.d/httpd-proxypass-alyvix.conf

    if [ -f ${FILE_TO_REMOVE} ]; then
        MD5SUM_REF='14986d3c764279079325548ee72ff3dc'
        MD5SUM=$(md5sum ${FILE_TO_REMOVE} | awk '{ print $1 }')

        if [ "${MD5SUM_REF}" = ${MD5SUM} ]; then
            echo rm -f ${FILE_TO_REMOVE}
        fi
    fi
}


if [[ $neteye_deployment == 'single_node' ]]; then
    remove_alyvix_httpd_proxy
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        remove_alyvix_httpd_proxy
        exit 0
    fi
    if [[ $neteye_node_type == 'elastic_only' ]]; then
        exit 0
    fi
    if [[ $neteye_node_type == 'voting_only' ]]; then
        exit 0
    fi
fi
if [[ $neteye_deployment == 'satellite' ]]; then
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255
