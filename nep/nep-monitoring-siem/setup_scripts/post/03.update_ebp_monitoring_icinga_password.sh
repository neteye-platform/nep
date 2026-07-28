#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh

function load_icinga_api_password() {
    local password_file="/root/.pwd_icinga2_nx_ebp_monitoring"
    local api_user_file="/neteye/shared/icinga2/conf/icinga2/conf.d/nx-ebp-monitoring-api-user.conf"
    local password=""

    if [[ -f "${password_file}" ]]; then
        cat "${password_file}"
        return 0
    fi

    if [[ -f "${api_user_file}" ]]; then
        password="$(sed -n 's/^[[:space:]]*password = "\(.*\)"$/\1/p' "${api_user_file}" | head -n 1)"
        if [[ -n "${password}" ]]; then
            printf '%s' "${password}"
            return 0
        fi
    fi

    echo "[!] Unable to locate the Icinga2 API password for nx-ebp-monitoring" >&2
    return 1
}

function update_plugin_password() {
    local plugin_files=("/neteye/shared/monitoring/plugins/check_elastic_remove_duplicate_ebp_iterations.py")
    local plugin_file=""
    local password=""
    local escaped_password=""
    local updated_files=0

    password="$(load_icinga_api_password)"
    if [[ -z "${password}" ]]; then
        echo "[!] Empty Icinga2 API password for nx-ebp-monitoring"
        exit 1
    fi

    escaped_password="$(printf '%s' "${password}" | sed 's/[&|\\]/\\&/g')"

    for plugin_file in "${plugin_files[@]}"; do
        if [[ ! -f "${plugin_file}" ]]; then
            continue
        fi

        if grep -q '^ICINGA_PASSWORD = ".*"$' "${plugin_file}"; then
            sed -i "s|^ICINGA_PASSWORD = \".*\"$|ICINGA_PASSWORD = \"${escaped_password}\"|" "${plugin_file}"
            echo "[i] Updated Icinga2 API password in ${plugin_file}"
            updated_files=1
            continue
        fi

        echo "[!] Cannot find ICINGA_PASSWORD assignment in ${plugin_file}"
        exit 1
    done

    if [[ ${updated_files} -eq 0 ]]; then
        echo "[i] No deployed EBP cleanup plugin found on this node. Skipping."
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    update_plugin_password
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        update_plugin_password
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