#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh

. /usr/share/neteye/scripts/rpm-functions.sh

function create_icinga_api_user() {
    local api_user="nx-ebp-monitoring"
    local password_file_name=".pwd_icinga2_nx_ebp_monitoring"
    local password_file="/root/${password_file_name}"
    local api_user_file="/neteye/shared/icinga2/conf/icinga2/conf.d/nx-ebp-monitoring-api-user.conf"
    local password=""

    if [[ ! -f "${password_file}" ]]; then
        if [[ -f "${api_user_file}" ]]; then
            password="$(sed -n 's/^[[:space:]]*password = "\([^"]*\)"$/\1/p' "${api_user_file}")"
        fi

        if [[ -n "${password}" ]]; then
            echo "[i] Reusing shared Icinga2 API password for ${api_user}"
            printf '%s\n' "${password}" > "${password_file}"
            chmod 600 "${password_file}"
        else
            echo "[i] Generating Icinga2 API password for ${api_user}"
            generate_and_save_pw "${password_file_name}"
        fi
    else
        echo "[i] Reusing existing Icinga2 API password for ${api_user}"
    fi

    if [[ ! -f "${password_file}" ]]; then
        echo "[!] Unable to read password file ${password_file}"
        exit 1
    fi

    password="$(cat "${password_file}")"

    echo "[i] Writing Icinga2 API user ${api_user} configuration"
    cat << EOF > "${api_user_file}"
/**
 * Used by the EBP duplicate iteration cleanup plugin to query service state.
 */
object ApiUser "nx-ebp-monitoring" {
  password = "${password}"
  // client_cn = ""

  permissions = [ "objects/query/Service" ]
}
EOF

    if systemctl is-active icinga2-master > /dev/null; then
        echo "[i] Reloading Icinga2 Master instance"
        systemctl reload icinga2-master
    else
        echo "[i] Icinga2 Master instance is not active. Skipping reload."
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_icinga_api_user
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        DRBD_MOUNTPOINT="icinga2"
        if is_drbd_mounted "$DRBD_MOUNTPOINT"; then
            create_icinga_api_user
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