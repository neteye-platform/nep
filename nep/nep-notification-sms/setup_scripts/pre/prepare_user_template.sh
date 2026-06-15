#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
# To allow End User to manually update States and Transitions and keep changes
# throughout all NEP Updates, an empty UT is created ONLY if NetEye hasn't it.
# Then, using Baskets, default custom variable settings and inheritance are
# forced
function add_uset_template() {
    channel="sms"
    echo "Create User Template for '$channel' channel"

    ## Check exist and create
    tmp=$(icingacli director user exist "nx-ut-$channel")
    if [[ $tmp == *"does not"* ]]; then
        echo " - Add user template 'nx-ut-$channel'"
        icingacli director user create "nx-ut-$channel" --object_type template \
            --imports nx-ut-abstract-base \
            --enable_notifications \
            --states "Critical" --states  "Down" --states "OK" --states "Up" \
            --types "Custom" --types "Problem" --types "Recovery"
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    add_uset_template
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icingaweb2"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            add_uset_template
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