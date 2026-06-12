#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

# Generates password for alyvix-check account.
# This account is used by the provided monitoring plugins to:
# - Get data from Alyvix Testcases (using Icingaweb2 session)
# - Get the list of monitored Test cases (by querying Icinga2 API)
# - Set status of services based on Test cases status (by querying Icinga2 API)

function create_alyvix_account_password() {
    username='alyvix-check'
    icingaweb_role=''
    icinga_pwd_file=".pwd_icinga2_alyvix_check"
    icingaweb_pwd_file=".pwd_icingaweb2_alyvix_check"

    if [[ -f "/root/$icinga_pwd_file" ]]; then
        echo "Password for Icinga2 account "alyvix-check" already exists. Skipping."
    else
        echo '[i] Generating password for Icinga2 account "alyvix-check"'
        icinga_pwd=$(generate_and_save_pw "$icinga_pwd_file")
    fi

    if [[ -f "/root/$icingaweb_pwd_file" ]]; then
        echo "Password for Icinga Web 2 account "alyvix-check" already exists. Skipping."
    else
        echo '[i] Generating password for Icinga Web 2 account "alyvix-check"'
        icingaweb_pwd=$(generate_and_save_pw "$icingaweb_pwd_file")
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_alyvix_account_password
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null; then
            create_alyvix_account_password
        else
            echo "[i] Inactive Cluster node. Skipping."
        fi

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
