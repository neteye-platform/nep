#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function import_mariadb_time_zones() {
    tz_count=$(mysql -BNe 'SELECT COUNT(*) FROM mysql.time_zone_name;')
    if [ "${tz_count}" -eq "0" ]; then
        echo "No Timezones defined on MariaDB. Importing default definitions..."
        mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql mysql
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    import_mariadb_time_zones

    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        import_mariadb_time_zones
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
