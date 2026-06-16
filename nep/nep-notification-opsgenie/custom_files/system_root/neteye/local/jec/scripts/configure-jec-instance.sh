#! /bin/bash

# Configure NetEye to connect and use a specific JSM Tenant.
# It will perform the following operations:
# - Configure and start a dedicated instance of Jira Edge Connector for NetEye
# - Create an Icinga Notification User that can be used to send notifications
#   to the associated JSM Tenant
# These changes will be performed only if:
# - The JEC instance config file doesn't exists
# - The Notification User doesn't exist
# - The default template for Notification User exists
#
# The only arguments are:
# - Instance name   : Local name of the instance; will be used as Unit Name and
#                     Notification User name, so please use something simple
#                     without spaces or special characters (like noc-instance-test)
# - JSM API Key: API Key for JSM OpsGenie Instance

. /usr/share/neteye/scripts/rpm-functions.sh

# Configuration constants
BASE_PATH="/neteye/local/jec"
CONF_PATH="${BASE_PATH}/conf"
TEMPLATE_FILE="${CONF_PATH}/neteye-jec.json.tpl"
NOTIFICATION_TEMPLATE="nx-ut-jsm-opsgenie"
PARAMETERIZED_UNIT_NAME="neteye-jec"
DRBD="icinga2"

# Prints help
function usage() {
    echo -e "Usage:\n"
    echo -e "  $0 [Instance Name] [JSM OpsGenie API KEY]\n"
    echo -e ""
    echo -e "   [Instance Name]        Identifier for JSM Integration. It will be used"
    echo -e "                          as service name as well as Icinga User name."
    echo -e "   [JSM OpsGenie API Key] API Key for target JSM OpsGenie Integration Team."
    echo -e ""

    exit 1
}

# Check the expected nuber of arguments from command line
function check_arguments_count() {
    if [ $1 -ne 2 ]; then
        echo -e "Error: Wrong number of arguments. Unable to continue."
        usage
    fi
}

# Ensure argument values are OK
# TODO: Provide stronger check for both instance name and API Key format
function check_arguments_value() {
    instance_name="$1"
    api_key="$2"

    if [ -z "${instance_name}" ]; then
        echo "No JEC Instance Name provided. Unable to continue."
        exit 1
    fi

    if [ -z "${api_key}" ]; then
        echo "No JSM OpsGenie API Key provided. Unable to continue."
        exit 1
    fi
}

# Ensure the Template File exists and can be used to store the API Key
function check_template_file() {
    if [ ! -f "${TEMPLATE_FILE}" ]; then
        echo "Fatal: Unable to locate JEC Instance Template file"
        exit 1
    fi

    output=$( grep "<API_KEY>" "${TEMPLATE_FILE}")
    if [ $? -ne 0 ]; then
        echo "Fatal: file \"${TEMPLATE_FILE}\" doesn't seem a valid JEC Instance Template file"
        exit 1
    fi
}

# Ensure SystemD Unit file is not present
function check_instance_file() {
    if [ -f "$1" ]; then
        echo "Fatal: Configuration file \"$1\" already exists. Unable to continue."
        exit 1
    fi
}

# Ensure Icinga has no User object with the provided name
# Pay attention: this function makes no difference between user obejcts and user templates
function check_icinga_user() {
    if icingacli director user exists "$1"; then
        echo "Fatal: Icinga User Object \"$1\" already exists. Unable to continue."

        exit 1
    fi
}

# Ensure Icinga has a User Template with the provided name
# Pay attention: this function makes no difference between user obejcts and user templates
function check_icinga_user_template() {
    if icingacli director user exists "$1"; then
        return 0
    fi

    echo "Fatal: Icinga User Template \"$1\" doesn't exist. Unable to continue."
    exit 1
}

# Trim leading and ending whitespaces from an argument
function trim_spaces() {
    text="$1"
    text="${text##*( )}"
    text="${text%%*( )}"

    echo $text
}

### MAIN PROGRAM ###
# Checks if the script has been invoked correctly
check_arguments_count $#

instance_name=$(trim_spaces "$1")
api_key=$(trim_spaces "$2")
check_arguments_value "${instance_name}" "${api_key}"

check_template_file

instance_file="${CONF_PATH}/${instance_name}.json"
notification_user="${instance_name}"
unit_name="${PARAMETERIZED_UNIT_NAME}@${instance_name}.service"

# Print all variable values, to allow easy identification of objects on server
echo 'Parameters summary:'
echo "- JEC Unit name                    : ${unit_name}"
echo "- JEC Instance name                : ${instance_name}"
echo "- JEC Instance configuration file  : ${instance_file}"
echo "- JEC Instance template file       : ${TEMPLATE_FILE}"
echo "- JSM OpsGenie API Key             : ${api_key}"
echo "- Icinga Notification User         : ${notification_user}"
echo "- Icinga Notification Uset Template: ${NOTIFICATION_TEMPLATE}"
echo ""

# Ensures all things are in place before beginning
echo "Checking arguments and status..."
if is_cluster && ! is_drbd_mounted "$DRBD" ; then
    echo "[i] Inactive Cluster Node, skipping."
else
    check_instance_file        "${instance_file}"
    check_icinga_user_template "${NOTIFICATION_TEMPLATE}"
    check_icinga_user          "${notification_user}"
fi

echo ""

# Configure NetEye for JEC Instance
echo "Creating new JEC Instance for NetEye"
# Create config file using the template
echo '- Creating configuration file for new JEC Instance'
cp -pa "${TEMPLATE_FILE}" "${instance_file}"
chown jec.jec "${instance_file}"
chmod 640 "${instance_file}"

echo '- Applying API KEY to JEC Instance configuration file'
sed -i "s/<API_KEY>/${api_key}/g" "${instance_file}"

# Creates the new User Object using Director, and stores the API key in it
# This way NEP Notifications will go to the right JSM Tenant
echo '- Create Icinga Notification User...'
if is_cluster && ! is_drbd_mounted "$DRBD" ; then
    echo "[i] Inactive Cluster Node, skipping."
else
    cat << EOF | icingacli director user create "${notification_user}" --json
{
    "display_name": "${notification_user}",
    "imports": [
        "${NOTIFICATION_TEMPLATE}"
    ],
    "object_name": "${notification_user}",
    "object_type": "object",
    "vars": {
        "nx_jsm_opsgenie_apikey": "${api_key}"
    }
}
EOF
fi

# Just try to start the new SystemD Unit: it is enough, since it is parameterized
echo "- Creating and starting JEC Instance Unit..."
systemctl enable "${unit_name}"
if is_cluster && ! is_drbd_mounted "$DRBD" ; then
    echo "[i] Inactive Cluster Node, not starting service instance."
else
    systemctl restart "${unit_name}"
    if systemctl is-active "${unit_name}"; then
        echo "JEC Instance Unit is now running"
    else
        echo "Fatal: Unable to start JEC instance Unit. Please manual troubleshoot this issue."
    fi
fi

# Done (whatever has been done). No deploy is performed.
# End User chan change the Display Name and other details of the User Object.
echo ""
echo "Done"
echo "You can update Icinga Notification User \"${notification_user}\" definition on Director and deploy configuration."

if is_cluster; then
    echo "Note: you are in a cluster environment. Run this script on all remaining nodes."
fi
