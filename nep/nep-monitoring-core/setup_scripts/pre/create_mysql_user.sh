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

function create_mysql_user() {
    echo "Creating MySQL Read Only user to Monitoring Core"

    mysql_username='icingareadonly'
    mysql_pwd_file="/root/.pwd_$mysql_username"

    mysql_host="mariadb.neteyelocal"
    mysql_port=3306
    FILE=/neteye/local/icinga2/data/spool/icinga2/.my.cnf

    if [ -f "$mysql_pwd_file" ]; then
        echo "$mysql_pwd_file already exists. Skip."
    else
        mysql_password=$(generate_and_save_pw "$mysql_username")
        echo " - Creating Database User for access"
        cat << EOF | mysql
CREATE USER IF NOT EXISTS '${mysql_username}'@'%' IDENTIFIED BY '${mysql_password}';
CREATE USER IF NOT EXISTS '${mysql_username}'@'localhost' IDENTIFIED BY '${mysql_password}';
ALTER USER '${mysql_username}'@'%' IDENTIFIED BY '${mysql_password}';
ALTER USER '${mysql_username}'@'localhost' IDENTIFIED BY '${mysql_password}';
FLUSH PRIVILEGES;
EOF

        echo " - Creating cnf file"
        cat << EOF > $FILE
[client]
host=mariadb.neteyelocal
user=${mysql_username}
password=${mysql_password}
EOF

        chown icinga:icinga $FILE

        if is_cluster ;then
            echo "[i] sync conf file on all nodes (exclude voting)"
            nodes=$(get_cluster_nodes_without_voting_hostname)

            for node in $nodes ; do rsync -avh $FILE $node:$FILE ; done
        fi

    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_mysql_user
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            create_mysql_user
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