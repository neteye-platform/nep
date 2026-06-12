#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh

##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

function add_vendor_to_list() {
    key="generic"
    name="Generic (NWC Checks)"
    FILE="/neteye/shared/icingaweb2/data/modules/fileshipper/nx-file-data/nx-vendor-list.csv"

    if grep -q "^${key}," $FILE ; then
        echo "Vendor '$key' already present... Nothing to do."
    else
    cat << EOF >> $FILE
$key,$name,string,null
EOF

    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    add_vendor_to_list
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        if is_drbd_mounted "icingaweb2"; then
            add_vendor_to_list
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