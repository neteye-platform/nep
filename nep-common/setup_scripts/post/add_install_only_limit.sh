#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
DNF_CONFIG_FILE=/etc/yum.conf
DNF_OPTION_KEY=installonly_limit
DNF_OPTION_VALUE=3

echo '[+] Add Install-only limit to DNF Configuration'
if grep "^\s*${DNF_OPTION_KEY}" "${DNF_CONFIG_FILE}"; then
    echo '[i] Option already exists. Skipping.'
else
    echo '[i] Option missing. Adding...'
    echo "${DNF_OPTION_KEY}=${DNF_OPTION_VALUE}" >> ${DNF_CONFIG_FILE}
fi

exit 0