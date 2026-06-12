#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function add_sudoers() {
    if [ -f "/etc/sudoers.d/SMcli" ]; then
        echo "SMcli already on sudoers."
        exit 0
    fi

    cat << EOF > /etc/sudoers.d/SMcli
icinga ALL = NOPASSWD: /opt/IBM_DS/client/SMcli
icinga ALL = NOPASSWD: /usr/lib/centreon/plugins/centreon_ibm_ds3000.pl
EOF
}

if [[ $neteye_deployment == 'single_node' ]]; then
    add_sudoers
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        add_sudoers
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
    add_sudoers
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255