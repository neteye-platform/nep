#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

CONSTANTS_FILE_PATH=/neteye/shared/icinga2/conf/icinga2/constants.conf
EMAIL_CONSTANTS_FILE_PATH=/neteye/shared/icinga2/conf/icinga2/conf.d/nx-constants-notification-email.conf

# Set the MailFrom
CONSTANT_FROM_NAME="NxEmailNotificationFrom"
CONSTANT_FROM_VALUE="icinga@$(get_neteye_hostname)"
CONSTANT_FROM_DESCRIPTION="NEP: Define sender for email-based notifications"

# Used to build http links to objects in the notifications
CONSTANT_MASTER_NAME="NxEmailNotificationMaster"
CONSTANT_MASTER_VALUE="$(get_neteye_hostname)"
CONSTANT_MASTER_DESCRIPTION="NEP: Define Master FQDN for email link"

# Mail Gateway (or relaying host) used to sent the current email
CONSTANT_GATEWAY_NAME="NxEmailNotificationGateway"
CONSTANT_GATEWAY_VALUE="127.0.0.1"
CONSTANT_GATEWAY_DESCRIPTION="NEP: Define Email gateway used for send"

constants_list="FROM MASTER GATEWAY"

function define_email_constants() {
    # Creates the constants file if not exists
    if [ ! -f ${EMAIL_CONSTANTS_FILE_PATH} ]; then
        echo "[i] Creating dedicated constants file"
        touch ${EMAIL_CONSTANTS_FILE_PATH}
        chmod 644 ${EMAIL_CONSTANTS_FILE_PATH}
        chown icinga.icinga ${EMAIL_CONSTANTS_FILE_PATH}

        # Moving existing constants in main constants file to the new file
        echo "[i] Migrating existing constants to dedicated constants file"
        for constant_topic in ${constants_list}; do
            constant_name="CONSTANT_${constant_topic}_NAME"
            echo "[d]   Migrating constant ${!constant_name}"
            grep ${!constant_name} ${CONSTANTS_FILE_PATH} >> ${EMAIL_CONSTANTS_FILE_PATH}
            sed -i "/${!constant_name}/d" ${CONSTANTS_FILE_PATH}
        done
    fi

    # Look for each constant in the constant file
    # if the constant is not defined, a default definition is provided
    for constant_topic in ${constants_list}; do
        constant_name="CONSTANT_${constant_topic}_NAME"
        constant_value="CONSTANT_${constant_topic}_VALUE"
        constant_description="CONSTANT_${constant_topic}_DESCRIPTION"
        grep "^\s*const\s*${!constant_name}\s*=" ${EMAIL_CONSTANTS_FILE_PATH} > /dev/null
        if [ $? == 0 ]; then
            echo "[i] Constant ${!constant_name} already defined. Skipping."
        else
            echo "[i] Defining constant ${!constant_name} with a predefined value"
            echo ""                                                 >> ${EMAIL_CONSTANTS_FILE_PATH}
            echo "/* ${!constant_description} */"                   >> ${EMAIL_CONSTANTS_FILE_PATH}
            echo "const ${!constant_name} = \"${!constant_value}\"" >> ${EMAIL_CONSTANTS_FILE_PATH}

        fi
    done
}

if [[ $neteye_deployment == 'single_node' ]]; then
    define_email_constants
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icinga2-master"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            define_email_constants
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