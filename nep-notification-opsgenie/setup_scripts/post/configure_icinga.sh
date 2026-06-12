#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
## Create Icinga2 API user for OEC and JEC
## PREREQUISITE: Opsgenie Edger Connector and Jira Edge Connector Password for Icinga must be created (during pre-setup phase)
# This kind of configuration must be performed only where Icinga2 Master is running
function configure_icinga() {
    OEC_PWD_FILE=.pwd_icinga_oec
    JEC_PWD_FILE=.pwd_icinga_jec
    ICINGA_OEC_USER_FILE=/neteye/shared/icinga2/conf/icinga2/conf.d/nx-oec-api-user.conf
    ICINGA_JEC_USER_FILE=/neteye/shared/icinga2/conf/icinga2/conf.d/nx-jsm-opsgenie-api-user.conf

    # Read Icinga2 API Password from file
    if [ -f "/root/$OEC_PWD_FILE" ]; then
        OEC_PWD=$(cat "/root/$OEC_PWD_FILE")
    else
        echo "Unable to get Opsgenie Edge Connector password for Icinga"
        exit 1
    fi
    if [ -f "/root/$JEC_PWD_FILE" ]; then
        JEC_PWD=$(cat "/root/$JEC_PWD_FILE")
    else
        echo "Unable to get Jira Edge Connector password for Icinga"
        exit 1
    fi

    RELOAD_ICINGA=1

    if [ -f "$ICINGA_OEC_USER_FILE" ]; then
        echo "Icinga2 permissions for Opsgenie Edge Connector already configured"
    else
        echo "Configuring permissions for Opsgenie Edge Connector on Icinga2 Master instance"
        cat << EOF > $ICINGA_OEC_USER_FILE
/**
 * Allows Opsgenie Edge Connector to do manage ack and comments on all oboects.
 */
object ApiUser "neteye-oec" {
  password = "${OEC_PWD}"
  // client_cn = ""

  permissions = [
    "actions/acknowledge-problem",
    "actions/remove-acknowledgement",
    "actions/add-comment"
  ]
}
EOF
        # Request restart of Icinga2 Master Instance
        RELOAD_ICINGA=0
    fi

    if [ -f "$ICINGA_JEC_USER_FILE" ]; then
        echo "Icinga2 permissions for Jira Edge Connector already configured"
    else
        echo "Configuring permissions for Jira Edge Connector on Icinga2 Master instance"
        cat << EOF > $ICINGA_JEC_USER_FILE
/**
 * Allows Jira Edge Connector to do manage ack and comments on all oboects.
 */
object ApiUser "neteye-jsm-opsgenie" {
  password = "${JEC_PWD}"
  // client_cn = ""

  permissions = [
    "actions/acknowledge-problem",
    "actions/remove-acknowledgement",
    "actions/add-comment"
  ]
}
EOF
        # Request restart of Icinga2 Master Instance
        RELOAD_ICINGA=0
    fi

    # If required, restart Icinga2 Master instance
    if [ $RELOAD_ICINGA == 0 ]; then
        if (systemctl is-active $SERVICE > /dev/null); then
            echo "Reloading Icinga2 Master instance"
            systemctl reload $SERVICE
        else
            echo "Icinga2 Master instance non running. Skipping reload."
        fi
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    configure_icinga
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icinga2-master"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            configure_icinga
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