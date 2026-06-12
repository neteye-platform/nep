#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

function create_authorized_keys() {
    monitoring_home=$(eval echo ~monitoring)
    monitoring_authorized_keys_file=${monitoring_home}/.ssh/authorized_keys
    icinga_home=$(eval echo ~icinga)
    icinga_public_key_file=${icinga_home}/.ssh/id_rsa.pub

    if [ ! -f ${authorized_keys_file} ]; then
        echo '[i] Creating authorized keys file for user monitoring'
        touch ${monitoring_authorized_keys_file}
        chmod 600 ${monitoring_authorized_keys_file}
        chown monitoring:monitoring ${monitoring_authorized_keys_file}
    fi
}

function get_keys_from_cluster_nodes() {
    monitoring_home=$(eval echo ~monitoring)
    monitoring_authorized_keys_file=${monitoring_home}/.ssh/authorized_keys
    icinga_home=$(eval echo ~icinga)
    icinga_public_key_file=${icinga_home}/.ssh/id_rsa.pub

    echo "[i] Get authorized_keys from all nodes"
    nodes=$(get_cluster_nodes_without_voting_hostname)
    for node in $nodes; do
        sed -i "/icinga@${node}$/d" ${monitoring_authorized_keys_file}
        ssh $node "cat ${icinga_public_key_file}" >> ${monitoring_authorized_keys_file}
    done
}

function get_keys_from_single_node() {
    monitoring_home=$(eval echo ~monitoring)
    monitoring_authorized_keys_file=${monitoring_home}/.ssh/authorized_keys
    icinga_home=$(eval echo ~icinga)
    icinga_public_key_file=${icinga_home}/.ssh/id_rsa.pub

    echo "[i] Get authorized_keys on single-node"
    sed -i "/icinga@$(hostname)$/d" ${monitoring_authorized_keys_file}
    cat ${icinga_public_key_file} >> ${monitoring_authorized_keys_file}
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_authorized_keys
    get_keys_from_single_node
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        create_authorized_keys
        get_keys_from_cluster_nodes
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