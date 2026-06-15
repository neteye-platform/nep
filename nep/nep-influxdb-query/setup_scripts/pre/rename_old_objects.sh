#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh
. /usr/share/neteye/secure_install/functions.sh

# Rename objects from an older setup
function rename_old_objects() {
    echo '[i] Renaming old custom variables and data fields...'
    cat << 'EOF' | mysql director
update icinga_command_var set varname='nx_centreon_influxdb_ssl_opt'               where varname='nx_centreon_influx_ssl_opt';
update icinga_command_var set varname='nx_centreon_influxdb_timeout'               where varname='nx_centreon_plugin_influxdb_timeout';
update icinga_command_var set varname='nx_centreon_influxdb_ssl'                   where varname='nx_centreon_plugin_influxdb_ssl';
update icinga_command_var set varname='nx_centreon_influxdb_hostname'              where varname='nx_centreon_plugin_influxdb_hostname';
update icinga_command_var set varname='nx_centreon_influxdb_port'                  where varname='nx_centreon_plugin_influxdb_port';
update icinga_command_var set varname='nx_centreon_influxdb_curl_opt'              where varname='nx_centreon_plugin_influxdb_curl_opt';
update icinga_command_var set varname='nx_centreon_influxdb_backend'               where varname='nx_centreon_plugin_influxdb_backend';
update icinga_command_var set varname='nx_centreon_influxdb_password'              where varname='nx_centreon_plugin_influxdb_password';
update icinga_command_var set varname='nx_centreon_influxdb_proto'                 where varname='nx_centreon_plugin_influxdb_proto';
update icinga_command_var set varname='nx_centreon_influxdb_ssl_opt'               where varname='nx_centreon_plugin_influxdb_ssl_opt';
update icinga_command_var set varname='nx_centreon_influxdb_username'              where varname='nx_centreon_plugin_influxdb_username';
update icinga_command_var set varname='nx_centreon_influxdb_http_peer_addr'        where varname='nx_centreon_plugin_influxdb_http_peer_addr';
update icinga_command_var set varname='nx_centreon_influxdb_query_aggregation'     where varname='nx_centreon_plugin_influxdb_aggregation';
update icinga_command_var set varname='nx_centreon_influxdb_query_critical_status' where varname='nx_centreon_plugin_influxdb_critical_status';
update icinga_command_var set varname='nx_centreon_influxdb_query_instance'        where varname='nx_centreon_plugin_influxdb_instance';
update icinga_command_var set varname='nx_centreon_influxdb_query_multiple_output' where varname='nx_centreon_plugin_influxdb_multiple_output';
update icinga_command_var set varname='nx_centreon_influxdb_query_output'          where varname='nx_centreon_plugin_influxdb_output';
update icinga_command_var set varname='nx_centreon_influxdb_query_query'           where varname='nx_centreon_plugin_influxdb_query';
update icinga_command_var set varname='nx_centreon_influxdb_query_warning_status'  where varname='nx_centreon_plugin_influxdb_warning_status';

update icinga_service_var set varname='nx_centreon_influxdb_ssl_opt'               where varname='nx_centreon_influx_ssl_opt';
update icinga_service_var set varname='nx_centreon_influxdb_timeout'               where varname='nx_centreon_plugin_influxdb_timeout';
update icinga_service_var set varname='nx_centreon_influxdb_ssl'                   where varname='nx_centreon_plugin_influxdb_ssl';
update icinga_service_var set varname='nx_centreon_influxdb_hostname'              where varname='nx_centreon_plugin_influxdb_hostname';
update icinga_service_var set varname='nx_centreon_influxdb_port'                  where varname='nx_centreon_plugin_influxdb_port';
update icinga_service_var set varname='nx_centreon_influxdb_curl_opt'              where varname='nx_centreon_plugin_influxdb_curl_opt';
update icinga_service_var set varname='nx_centreon_influxdb_backend'               where varname='nx_centreon_plugin_influxdb_backend';
update icinga_service_var set varname='nx_centreon_influxdb_password'              where varname='nx_centreon_plugin_influxdb_password';
update icinga_service_var set varname='nx_centreon_influxdb_proto'                 where varname='nx_centreon_plugin_influxdb_proto';
update icinga_service_var set varname='nx_centreon_influxdb_ssl_opt'               where varname='nx_centreon_plugin_influxdb_ssl_opt';
update icinga_service_var set varname='nx_centreon_influxdb_username'              where varname='nx_centreon_plugin_influxdb_username';
update icinga_service_var set varname='nx_centreon_influxdb_http_peer_addr'        where varname='nx_centreon_plugin_influxdb_http_peer_addr';
update icinga_service_var set varname='nx_centreon_influxdb_query_aggregation'     where varname='nx_centreon_plugin_influxdb_aggregation';
update icinga_service_var set varname='nx_centreon_influxdb_query_critical_status' where varname='nx_centreon_plugin_influxdb_critical_status';
update icinga_service_var set varname='nx_centreon_influxdb_query_instance'        where varname='nx_centreon_plugin_influxdb_instance';
update icinga_service_var set varname='nx_centreon_influxdb_query_multiple_output' where varname='nx_centreon_plugin_influxdb_multiple_output';
update icinga_service_var set varname='nx_centreon_influxdb_query_output'          where varname='nx_centreon_plugin_influxdb_output';
update icinga_service_var set varname='nx_centreon_influxdb_query_query'           where varname='nx_centreon_plugin_influxdb_query';
update icinga_service_var set varname='nx_centreon_influxdb_query_warning_status'  where varname='nx_centreon_plugin_influxdb_warning_status';

update icinga_host_var set varname='nx_centreon_influxdb_ssl_opt'                  where varname='nx_centreon_influx_ssl_opt';
update icinga_host_var set varname='nx_centreon_influxdb_timeout'                  where varname='nx_centreon_plugin_influxdb_timeout';
update icinga_host_var set varname='nx_centreon_influxdb_ssl'                      where varname='nx_centreon_plugin_influxdb_ssl';
update icinga_host_var set varname='nx_centreon_influxdb_hostname'                 where varname='nx_centreon_plugin_influxdb_hostname';
update icinga_host_var set varname='nx_centreon_influxdb_port'                     where varname='nx_centreon_plugin_influxdb_port';
update icinga_host_var set varname='nx_centreon_influxdb_curl_opt'                 where varname='nx_centreon_plugin_influxdb_curl_opt';
update icinga_host_var set varname='nx_centreon_influxdb_backend'                  where varname='nx_centreon_plugin_influxdb_backend';
update icinga_host_var set varname='nx_centreon_influxdb_password'                 where varname='nx_centreon_plugin_influxdb_password';
update icinga_host_var set varname='nx_centreon_influxdb_proto'                    where varname='nx_centreon_plugin_influxdb_proto';
update icinga_host_var set varname='nx_centreon_influxdb_ssl_opt'                  where varname='nx_centreon_plugin_influxdb_ssl_opt';
update icinga_host_var set varname='nx_centreon_influxdb_username'                 where varname='nx_centreon_plugin_influxdb_username';
update icinga_host_var set varname='nx_centreon_influxdb_http_peer_addr'           where varname='nx_centreon_plugin_influxdb_http_peer_addr';
update icinga_host_var set varname='nx_centreon_influxdb_query_aggregation'        where varname='nx_centreon_plugin_influxdb_aggregation';
update icinga_host_var set varname='nx_centreon_influxdb_query_critical_status'    where varname='nx_centreon_plugin_influxdb_critical_status';
update icinga_host_var set varname='nx_centreon_influxdb_query_instance'           where varname='nx_centreon_plugin_influxdb_instance';
update icinga_host_var set varname='nx_centreon_influxdb_query_multiple_output'    where varname='nx_centreon_plugin_influxdb_multiple_output';
update icinga_host_var set varname='nx_centreon_influxdb_query_output'             where varname='nx_centreon_plugin_influxdb_output';
update icinga_host_var set varname='nx_centreon_influxdb_query_query'              where varname='nx_centreon_plugin_influxdb_query';
update icinga_host_var set varname='nx_centreon_influxdb_query_warning_status'     where varname='nx_centreon_plugin_influxdb_warning_status';

update director_datafield set varname='nx_centreon_influxdb_ssl_opt'               where varname='nx_centreon_influx_ssl_opt';
update director_datafield set varname='nx_centreon_influxdb_timeout'               where varname='nx_centreon_plugin_influxdb_timeout';
update director_datafield set varname='nx_centreon_influxdb_ssl'                   where varname='nx_centreon_plugin_influxdb_ssl';
update director_datafield set varname='nx_centreon_influxdb_hostname'              where varname='nx_centreon_plugin_influxdb_hostname';
update director_datafield set varname='nx_centreon_influxdb_port'                  where varname='nx_centreon_plugin_influxdb_port';
update director_datafield set varname='nx_centreon_influxdb_curl_opt'              where varname='nx_centreon_plugin_influxdb_curl_opt';
update director_datafield set varname='nx_centreon_influxdb_backend'               where varname='nx_centreon_plugin_influxdb_backend';
update director_datafield set varname='nx_centreon_influxdb_password'              where varname='nx_centreon_plugin_influxdb_password';
update director_datafield set varname='nx_centreon_influxdb_proto'                 where varname='nx_centreon_plugin_influxdb_proto';
update director_datafield set varname='nx_centreon_influxdb_ssl_opt'               where varname='nx_centreon_plugin_influxdb_ssl_opt';
update director_datafield set varname='nx_centreon_influxdb_username'              where varname='nx_centreon_plugin_influxdb_username';
update director_datafield set varname='nx_centreon_influxdb_http_peer_addr'        where varname='nx_centreon_plugin_influxdb_http_peer_addr';
update director_datafield set varname='nx_centreon_influxdb_query_aggregation'     where varname='nx_centreon_plugin_influxdb_aggregation';
update director_datafield set varname='nx_centreon_influxdb_query_critical_status' where varname='nx_centreon_plugin_influxdb_critical_status';
update director_datafield set varname='nx_centreon_influxdb_query_instance'        where varname='nx_centreon_plugin_influxdb_instance';
update director_datafield set varname='nx_centreon_influxdb_query_multiple_output' where varname='nx_centreon_plugin_influxdb_multiple_output';
update director_datafield set varname='nx_centreon_influxdb_query_output'          where varname='nx_centreon_plugin_influxdb_output';
update director_datafield set varname='nx_centreon_influxdb_query_query'           where varname='nx_centreon_plugin_influxdb_query';
update director_datafield set varname='nx_centreon_influxdb_query_warning_status'  where varname='nx_centreon_plugin_influxdb_warning_status';
EOF


    declare -A command_objects
    declare -A service_objects
    command_objects["nx-ct-centreon-plugins-influxdb"]="nx-ct-centreon-influxdb"
    command_objects["nx-c-centreon-plugins-influxdb-query"]="nx-c-centreon-influxdb-query"

    service_objects["nx-st-agentless-centreon-plugin"]="nx-st-agentless-influxdb"
    service_objects["nx-st-centreon-influxdb"]="nx-st-agentless-influxdb-centreon"
    service_objects["nx-st-centreon-influxdb-query"]="nx-st-agentless-influxdb-centreon-query"


    echo "[i] Renaming legacy Director Objects"

    ## Rename command set objects
    for s in "${!command_objects[@]}"; do
        tmp=$(icingacli director command exist "$s")
        if [[ $tmp != *"does not"* ]]; then
            echo " - Rename legacy object ${s} to ${command_objects[$s]}"
            icingacli director command set "$s" --object_name "${command_objects[$s]}"
        fi
    done

    ## Rename service set objects
    for s in "${!service_objects[@]}"; do
        tmp=$(icingacli director service exist "$s")
        if [[ $tmp != *"does not"* ]]; then
            echo " - Rename legacy object ${s} to ${service_objects[$s]}"
            icingacli director service set "$s" --object_name "${service_objects[$s]}"
        fi
    done
}

echo '[i] Renaming objects from previous versions of this NEP'

if [[ $neteye_deployment == 'single_node' ]]; then
    rename_old_objects
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            rename_old_objects
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