#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function create_alivyx_account_on_icinga2() {
    echo '[i] Creating Icinga2 API user account "alyvix-check"'
    icinga_pwd_file="/root/.pwd_icinga2_alyvix_check"
    if [ ! -f "${icinga_pwd_file}" ]; then
        echo '[!] Unable to get account password from pwd file'
        exit 1
    fi

    api_user_file=/neteye/shared/icinga2/conf/icinga2/conf.d/nx-alyvix-service-users.conf
    icinga_pwd="$(cat "${icinga_pwd_file}")"
    if [ -f "${api_user_file}" ]; then
        echo '[i] User account should already exist. Skipping.'
    else
        cat << EOF > "${api_user_file}"
/**
* Used by Alyvix Service Check plugin to identify and set status of the proper (passive) services
*/
object ApiUser "alyvix-check" {
password = "${icinga_pwd}"
// client_cn = ""

permissions = [ "objects/query/Host", "objects/query/Service", "actions/process-check-result" ]
}
EOF

        chmod 644 "${icinga_pwd_file}"
        chown icinga.icinga "${icinga_pwd_file}"

        echo '[!] Done. Reload Icinga2 to enable the new API user account'
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_alivyx_account_on_icinga2
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icinga2-master"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            create_alivyx_account_on_icinga2
        else
            echo "[i] Inactive Cluster Node. Skipping."
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
