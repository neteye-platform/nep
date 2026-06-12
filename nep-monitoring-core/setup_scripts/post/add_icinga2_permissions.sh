#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function add_icing_permissions() {
    mysql_username='icingareadonly'

    echo " - Add Database permissions for user "$mysql_username" access"
        cat << EOF | mysql
GRANT SELECT ON director.icinga_zone TO '${mysql_username}'@'localhost';
GRANT SELECT ON director.icinga_zone TO '${mysql_username}'@'%';
GRANT SELECT ON director.icinga_host TO '${mysql_username}'@'localhost';
GRANT SELECT ON director.icinga_host TO '${mysql_username}'@'%';
FLUSH PRIVILEGES;
EOF
}

if [[ $neteye_deployment == 'single_node' ]]; then
    add_icing_permissions
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            add_icing_permissions
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