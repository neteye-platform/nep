#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function update_cv_name() {
    #Custom Variable name
    old_cv_name="nx_oracle_health_tablespace_name"
    new_cv_name="nx_oracle_health_name"

    #Default output message and dummy_host state
    # output_message="UNKNOWN: something went wrong"
    # exit_state=0

    #TODO
    for table in "icinga_command_var" "icinga_host_var" "icinga_notification_var" "icinga_service_var" "icinga_service_set_var" "icinga_user_var"
    do
        update_cv_name="UPDATE $table SET varname='$new_cv_name' WHERE varname='$old_cv_name'"
        result=$(mysql 'director' --execute "$update_cv_name")
        result_status=$?
        if [ "$result_status" -gt "0" ]; then
            output_message="ERROR during $update_cv_name"
            exit $result_status
        fi
    done

    exit $?
}

if [[ $neteye_deployment == 'single_node' ]]; then
    update_cv_name
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            update_cv_name
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