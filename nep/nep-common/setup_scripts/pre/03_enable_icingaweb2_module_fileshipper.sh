#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

function enable_fileshipper_module() {
    SERVICE="php-fpm"
    if systemctl is-active "$SERVICE" > /dev/null; then
        echo "[i] Enabling Icingaweb2 Module Fileshipper"
        icingacli module enable fileshipper

        create_fileshipper_config_files
    else
        echo "[i] Icingaweb2 is not active. Skipping."
    fi
}

function create_fileshipper_config_files() {
    base_nep="/usr/share/neteye/nep/"
    FILE="/neteye/shared/icingaweb2/conf/modules/fileshipper/imports.ini"

    if [ ! -f "$FILE" ]; then
        echo " - No configuration found for module FileShipper. Applying default settings."
        touch $FILE
    fi

    if grep -qxF '[NX NEP Private Data]' $FILE ; then
        echo " - NEP Data file source already exist, nothing to do."
    else
        ## Create NEP Data import definition in FileShipper
        echo " - Adding NEP Data file source to FileShipper configuration"
        cat << EOF >> $FILE

[NX NEP Private Data]
basedir="/neteye/shared/icingaweb2/data/modules/fileshipper/nx-file-data/"

EOF

        ## Fix ownership of folder and files
        chown -R root:icingaweb2 /neteye/shared/icingaweb2/conf/modules/fileshipper/
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    enable_fileshipper_module
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        enable_fileshipper_module
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