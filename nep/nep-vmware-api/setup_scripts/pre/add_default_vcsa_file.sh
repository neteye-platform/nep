#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function add_vcsa_authentication_file() {
    echo "Adding VCSA file on Icinga2 Master"

    SERVICE="icingaweb2"
    if is_cluster && ! is_active "$SERVICE" ; then
        echo " Not a cluster node. Skipping."
        exit 0
    fi

    if [ -f "/neteye/shared/icinga2/conf/vmware-auth-files/generic-vcsa" ]; then
        echo "VCSA file already exist."
        exit 0
    fi

    mkdir -p /neteye/shared/icinga2/conf/vmware-auth-files/
    touch /neteye/shared/icinga2/conf/vmware-auth-files/generic-vcsa
    chown -R root:icinga /neteye/shared/icinga2/conf/vmware-auth-files

    cat << EOF > /neteye/shared/icinga2/conf/vmware-auth-files/generic-vcsa
username=XXXX@
password=
EOF

    chmod 640 /neteye/shared/icinga2/conf/vmware-auth-files/generic-vcsa
}

if [[ $neteye_deployment == 'single_node' ]]; then
    add_vcsa_authentication_file
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icinga2-master"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            add_vcsa_authentication_file
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
    add_vcsa_authentication_file
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255