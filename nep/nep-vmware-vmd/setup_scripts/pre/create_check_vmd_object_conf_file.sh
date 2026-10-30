#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function create_conf_file() {
        config_file_path=/neteye/shared/monitoring/plugins/check_vmd_object.conf

        echo "[i] Adding Configuration file for check_vmd_object"
        if [ -f ${config_file_path} ]
        then
                echo " - Config file already present, skipping.";
        else
                echo " - Creating Config file ${config_file_path}"
                cat << 'EOF' > ${config_file_path}
[VMDDB]
username = vspheredb
password = ChangeMe!
EOF
                echo " - Configuration file created. Please, remember to replace Username and Password inside it!"
                echo "[i] Done"
        fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_conf_file
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        create_conf_file
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