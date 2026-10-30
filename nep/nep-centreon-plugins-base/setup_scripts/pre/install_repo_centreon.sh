#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
# Install Centreon Repo's definitions version 23.04

# From version 23.04, repo definitions are no more shipper with package centreon-release.
# In fact, centreon-release is no more. Must use the official procedure reported at the following URL:
#   https://docs.centreon.com/docs/installation/installation-of-a-poller/using-packages/#install-the-repositories

function create_folder_for_temp_files() {
    if [ ! -d "/neteye/shared/icinga2/data/lib/centreon-plugins/" ]; then
        mkdir /neteye/shared/icinga2/data/lib/centreon-plugins/
        chown icinga:icingaweb2 /neteye/shared/icinga2/data/lib/centreon-plugins/
    fi
}

function install_centreon_repo() {
    # If installed, remove rpm centreon-release
    echo 'Checking if Centreon Repo definition is shipped via RPM...'
    if rpm -q centreon-release; then
        echo 'Removing old repo definitions'
        dnf -y remove centreon-release
    fi

    # Add new repo definitions
    echo 'Adding Centreon Repo definitions using DNF Config Manager'
    dnf config-manager --add-repo https://packages.centreon.com/rpm-standard/25.10/el8/centreon-25.10.repo
    if [ $? -eq 0 ]; then
        echo ' Done'
    else
        echo ' Unable to add Centreon Repo definitions'
        exit 1
    fi

    # Disable all Centreon Repos, to avoid future issues with dnf update
    # If disabling fails, the script terminates with an error
    echo 'Disabling repositories...'
    for repo in $(dnf repolist --enabled | grep -e '^centreon' | awk '{ print $1 }'); do
        echo -n "Disabling repo $repo..."
        dnf config-manager --disable $repo > /dev/null
        if [ $? -eq 0 ]; then
            echo ' Done'
        else
            echo ' Failed'
            exit 1
        fi
    done
}


if [[ $neteye_deployment == 'single_node' ]]; then
    install_centreon_repo
    create_folder_for_temp_files
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        install_centreon_repo
        SERVICE="icinga2-master"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            create_folder_for_temp_files
        else
            echo "[i] Inactive Cluster Node. Skipping."
        fi

        exit 0
    fi
    if [[ $neteye_node_type == 'elastic_only' ]]; then
        install_centreon_repo
        exit 0
    fi
    if [[ $neteye_node_type == 'voting_only' ]]; then
        exit 0
    fi
fi
if [[ $neteye_deployment == 'satellite' ]]; then
    install_centreon_repo
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255