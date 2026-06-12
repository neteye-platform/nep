#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function clean_tornado_rules() {
    ## Rename folder before 4.39
    if [ -d '/neteye/shared/tornado/conf/rules.d/master/elproxy_verification' ];then
        echo "[w] Existing old Tornado rules 'elproxy_verification'. Migration..."
        rm -f /neteye/shared/tornado/conf/rules.d/master/elproxy_verification/elproxy_verification_ruleset/0000000010_elproxy_verification.json /neteye/shared/tornado/conf/rules.d/master/elproxy_verification/elproxy_verification_ruleset/0000000020_elproxy_duplicates_removal.json
        mv /neteye/shared/tornado/conf/rules.d/master/elproxy_verification/elproxy_verification_ruleset /neteye/shared/tornado/conf/rules.d/master/elproxy_verification/nx_elproxy_verification_rules
        mv /neteye/shared/tornado/conf/rules.d/master/elproxy_verification /neteye/shared/tornado/conf/rules.d/master/nx_elproxy_verification
        echo "[i] Migration old Tornado rules complete!"
    fi

    # Clean all Tornado Rules NX before import
    declare -a list_torando_rules=("nx_elastic_dataset" "nx_elastic_transforms" "nx_elastic_watchers" "nx_elproxy_verification")
    for rule in "${list_tornado_rules[@]}";do
        rm -rf /neteye/shared/tornado/conf/rules.d/master/${rule}
    done
    echo "[i] Rule nx_ cleaned before import"
}

if [[ $neteye_deployment == 'single_node' ]]; then
    clean_tornado_rules
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="tornado"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            clean_tornado_rules
        else
            echo "[i] Inactive Cluster Node. Skipping."
        fi

        exit 0
    fi
    if [[ $neteye_node_type == 'elastic_only' ]]; then
        # Place your code here
        exit 0
    fi
    if [[ $neteye_node_type == 'voting_only' ]]; then
        # Place your code here
        exit 0
    fi
fi
if [[ $neteye_deployment == 'satellite' ]]; then
    # Place your code here
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255