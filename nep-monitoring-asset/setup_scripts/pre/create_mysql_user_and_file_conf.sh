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

function create_mysql_user_and_conf() {
    echo "Creating MySQL Read Only user to Monitoring Asset"

    mysql_username='assetmanagement'
    mysql_pwd_file="/root/.pwd_$mysql_username"

    mysql_host="mariadb.neteyelocal"
    mysql_port=3306

    if [ -f "$mysql_pwd_file" ]; then
        echo "$mysql_pwd_file already exists. Skip."
    else
        mysql_password=$(generate_and_save_pw "$mysql_username")
        echo " - Creating Database User for access"
        cat << EOF | mysql
CREATE USER IF NOT EXISTS '${mysql_username}'@'%' IDENTIFIED BY '${mysql_password}';
CREATE USER IF NOT EXISTS'${mysql_username}'@'localhost' IDENTIFIED BY '${mysql_password}';
GRANT SELECT on glpi.* to '${mysql_username}'@'localhost';
GRANT SELECT on ocsweb.* to '${mysql_username}'@'localhost';
GRANT SELECT on glpi.* to '${mysql_username}'@'%';
GRANT SELECT on ocsweb.* to '${mysql_username}'@'%';
FLUSH PRIVILEGES;
EOF

        echo "Create Asset config file"
        cat << EOF > /neteye/shared/monitoring/plugins/check_assetmanagement.conf
\$mariadb_host = "${mysql_host}";

\$ocs_db = "ocsweb";
\$ocs_user = "${mysql_username}";
\$ocs_pass = "${mysql_password}";

\$glpi_db ="glpi";
\$glpi_user = "${mysql_username}";
\$glpi_pass = "${mysql_password}";
EOF
    fi
}

function sync_plugin_conf_on_cluster_nodes() {
    echo "[i] sync conf file on all nodes (exclude voting)"
    nodes=$(get_cluster_nodes_without_voting_hostname)

    for node in $nodes ; do rsync -avh /neteye/shared/monitoring/plugins/check_assetmanagement.conf $node:/neteye/shared/monitoring/plugins/ ; done
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_mysql_user_and_conf
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            create_mysql_user_and_conf
            sync_plugin_conf_on_cluster_nodes
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
