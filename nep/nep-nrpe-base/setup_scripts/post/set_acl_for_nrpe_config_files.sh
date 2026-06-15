#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################

function set_acl_for_nrpe_config_files() {
    echo 'Getting NetEye Corporate IPs'
    # Get the main IP of NetEye
    # On a Cluster, it is the VIP from PCS
    # On a single node, function get_neteye_ip returns 127.0.0.1, so the IP must be found "manually"
    neteye_ips=$(get_neteye_ip)
    if [ "${neteye_ips}" == "127.0.0.1" ]; then
        # In case of a single node, must lookup for the host fqdn on /etc/hosts file
        # assumptions: hostname of the host is the real FQDN on NetEye and its IP is stored into /etc/hosts
        neteye_ips=$(awk '{for (i=1; i<=NF; i++) if ($i == "'$(hostname)'") print $0}' /etc/hosts | awk '{ print $1 }')
    fi

    # In a cluster environment, loop into /etc/neteye-cluster to find the extenal name of each cluster node,
    # then resolves all names into IPs using /etc/hosts file
    if [ -f /etc/neteye-cluster ]; then
        for node in $(cat /etc/neteye-cluster | jq '.Nodes[].hostname_ext')
        do
                node_ip=$(eval grep $node /etc/hosts | awk '{ print $1 }')
                neteye_ips="${neteye_ips},${node_ip}"
        done
    fi

    echo ${neteye_ips}

    echo "Updating NRPE Config files for agents"
    sed -i "s/<NETEYE_IPS>/${neteye_ips}/g" /neteye/shared/icinga2/data/nrpe/nsclient.ini
    sed -i "s/<NETEYE_IPS>/${neteye_ips}/g" /neteye/shared/icinga2/data/nrpe/nrpe.cfg
}

if [[ $neteye_deployment == 'single_node' ]]; then
    set_acl_for_nrpe_config_files
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icinga2-master"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            set_acl_for_nrpe_config_files
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