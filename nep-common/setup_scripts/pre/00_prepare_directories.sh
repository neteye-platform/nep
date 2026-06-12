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

# Support function: Create directory if not exists
function create_directory() {
    directory_path="$1"
    directory_description="$2"

    if [ -d ${directory_path} ] ; then
        echo " - Directory \"${directory_description}\" already exists"
    else
        echo " - Creating directory \"${directory_description}\""
        mkdir -p ${directory_path}
    fi
}

# Directories that should be available on all nodes
function create_common_directories() {
    create_directory "/neteye/shared/monitoring/plugins"                                "Plugin Contribution Directory"
}

# Directories that should be available on all Operative Nodes
function create_icingaweb_module_source_directories() {
    echo '[i] Creating directories on Operative Nodes...'
    create_directory "/usr/share/icingaweb2/public/img/nep"                             "Main Icons folder for NEP templates"
    create_directory "/usr/share/icingaweb2/modules/nep/support-scripts/holidays"		"Support script for Icingaweb2"
}

# Directories that should be available only where Icingaweb2 is running
function create_icingaweb_module_conf_directories() {
    echo '[i] Creating Icingaweb2 Modules Configuration directories...'
    create_directory "/neteye/shared/icingaweb2/conf/modules/fileshipper/"              "Fileshipper configuration directory"
    create_directory "/neteye/shared/icingaweb2/data/modules/fileshipper/nx-file-data/" "Fileshipper file repository for NEP"
    create_directory "/neteye/shared/icingaweb2/conf/modules/nep/"						"Config file for Icingaweb2"
}

echo '[i] Creating Common directories...'
create_common_directories

if [[ $neteye_deployment == 'single_node' ]]; then
    # On a Single Node, all directories must be created
    echo '[i] Creating directories on Single Node Setup...'
    create_icingaweb_module_source_directories
    create_icingaweb_module_conf_directories

    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    # On a Cluster Setup, some directories must be created only where the DRBD file system is mounted
    if [[ $neteye_node_type == 'node' ]]; then
        echo '[i] Creating Support Directorie for Icingaweb2 Modules...'
        create_icingaweb_module_source_directories

        SERVICE="icingaweb2"
        if is_drbd_mounted "$SERVICE"; then
            echo '[i] Creating Shared directories for Icingaweb2 Modules...'
            create_icingaweb_module_conf_directories
        else
            echo "[i] Icingaweb2 Filesystem not mounted, skipping Shared directories creation"
        fi

        exit 0
    fi
    # On other nodes, does nothing
    if [[ $neteye_node_type == 'elastic_only' ]]; then
        exit 0
    fi
    if [[ $neteye_node_type == 'voting_only' ]]; then
        exit 0
    fi
fi
if [[ $neteye_deployment == 'satellite' ]]; then
    # Nothing to do on satellites
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255