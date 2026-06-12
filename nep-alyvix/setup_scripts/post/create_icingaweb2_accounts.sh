#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function create_alyvix_account_on_icingaweb() {
    echo '[i] Creating Icinga Web 2 user account "alyvix-check"'
    icingaweb_pwd_file="/root/.pwd_icingaweb2_alyvix_check"
    if [ ! -f "${icingaweb_pwd_file}" ]; then
        echo '[!] Unable to get account password from pwd file'
        exit 1
    fi

    icingaweb_user='alyvix-check'
    icingaweb_pwd="$(cat "${icingaweb_pwd_file}")"
    icingaweb_pwd_hash="$(php -r "echo password_hash(\"${icingaweb_pwd}\", PASSWORD_DEFAULT);")"
    RET=$?
    if [ $RET -ne 0 ] ; then
        echo "  [-] Error while generating the hash of the password for the icingaweb2 user"
        exit 2
    fi

    if mysql icingaweb2 -e "INSERT INTO icingaweb_user (name, active, password_hash, ctime) VALUES('${icingaweb_user}', 1, '${icingaweb_pwd_hash}', now()) ON DUPLICATE KEY UPDATE password_hash='${icingaweb_pwd_hash}';"; then
        echo -e "[+] Account created"
    else
        echo "[-] Error adding ${icingaweb_user} user"
        exit 3;
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_alyvix_account_on_icingaweb
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            create_alyvix_account_on_icingaweb
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
