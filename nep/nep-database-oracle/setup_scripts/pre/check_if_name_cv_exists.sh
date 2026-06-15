#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function check_if_cv_exists() {
    #Custom Variable name
    cv_name="name"

    #Default output message and dummy_host state
    output_message="UNKNOWN: something went wrong"
    exit_state=2

    #TODO
    cv_count=0

    for table in "icinga_command_var" "icinga_host_var" "icinga_notification_var" "icinga_service_var" "icinga_service_set_var" "icinga_user_var" "icinga_var"
    do
        get_cv_count="SELECT COUNT(*) AS count from $table where varname='$cv_name'"
        result=$(mysql 'director' --execute "$get_cv_count" | grep -v count)
        cv_count=$((cv_count + result))
    done

    if [ "$cv_count" -gt "0" ]; then
        output_message="CRITICAL: $cv_name exists"
        exit_state=1
    fi

    if [ "$cv_count" -eq "0" ]; then
        output_message="OK: $cv_name does not exist"
        exit_state=0
    fi

    echo $output_message
    exit $exit_state
}

if [[ $neteye_deployment == 'single_node' ]]; then
    check_if_cv_exists
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            check_if_cv_exists
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