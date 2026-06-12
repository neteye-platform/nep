#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################

. /usr/share/neteye/scripts/rpm-functions.sh

# Create the Icingaweb2 Role that allows Alyvix Monitoring Plugin to get Testcase data
# If a user uses this role to log into NetEye, it will not see any test case, while the
# Plugin is still able to get all the required data to work.

ICINGAWEB2_DRBD_RESOURCE_NAME="icingaweb2_drbd_fs"

if is_cluster && ! is_active "$ICINGAWEB2_DRBD_RESOURCE_NAME" ; then
    echo "[i] Inactive Cluster Node, skipping"
    return 0
fi


function create_alyvix_service_role() {
    ICINGAWEB2_ROLES_FILE="/neteye/shared/icingaweb2/conf/roles.ini"
    ROLE_NAME="alyvix-service-check"
    ROLE_DEFINITION="
\n\
[${ROLE_NAME}]\n\
users = \"alyvix-check\"\n\
permissions = \"module/alyvix,alyvix/*,module/neteye\"\n\
name = \"alyvix-service-check\""

    if ! grep "\[${ROLE_NAME}\]" "${ICINGAWEB2_ROLES_FILE}" ; then
        echo "  [i] Adding role '${ROLE_NAME}' to $ICINGAWEB2_ROLES_FILE"
        if echo -e "$ROLE_DEFINITION" >> "${ICINGAWEB2_ROLES_FILE}" ; then
            echo "    [i] Role '${ROLE_NAME}' correctly added to $ICINGAWEB2_ROLES_FILE"
        else
            echo "    [-] Error while adding role '${ROLE_NAME}' to $ICINGAWEB2_ROLES_FILE"
            exit 1
        fi
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_alyvix_service_role
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        if is_active "$ICINGAWEB2_DRBD_RESOURCE_NAME" ; then
            create_alyvix_service_role
        else
            echo "[i] Inactive Cluster Node, skipping"
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
