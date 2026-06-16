#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function install_sudo() {
    yum install sudo -y
}

function ensure_monitoring_user_exists() {
    if [ -f "/etc/sudoers.d/icinga" ]; then
        echo "Icinga sudoers already exists. Skip."
    else
        create_monitoring_user
    fi
}

function create_monitoring_user() {
    icinga_home=$(eval echo ~icinga)
    #Creating objects on all nodes
    sudo -u icinga ssh-keygen -t rsa -N '' -f $icinga_home/.ssh/id_rsa <<< n
    useradd monitoring
    monitoring_home=$(eval echo ~monitoring)
    install -d -m 700 -o monitoring -g monitoring $monitoring_home/.ssh

    #Adding sudoers permissions for icinga on local node
    echo 'icinga ALL = NOPASSWD: /usr/sbin/crm_mon' > /etc/sudoers.d/icinga

    #sudores permissions
    chmod 644 /etc/sudoers.d/icinga
    chown root:root /etc/sudoers.d/icinga
}

if [[ $neteye_deployment == 'single_node' ]]; then
    install_sudo
    ensure_monitoring_user_exists
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        install_sudo
        ensure_monitoring_user_exists
        exit 0
    fi
    if [[ $neteye_node_type == 'elastic_only' ]]; then
        install_sudo
        exit 0
    fi
    if [[ $neteye_node_type == 'voting_only' ]]; then
        install_sudo
        exit 0
    fi
fi
if [[ $neteye_deployment == 'satellite' ]]; then
    install_sudo
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255