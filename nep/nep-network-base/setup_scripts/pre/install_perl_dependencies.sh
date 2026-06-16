#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh

##########################################
## Script main code: add your code here ##
##########################################
function install_perl_dependencies() {
    dnf install -y perl-File-Slurp.noarch perl-JSON-XS
}


if [[ $neteye_deployment == 'single_node' ]]; then
    install_perl_dependencies
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        install_perl_dependencies
        exit 0
    fi
    if [[ $neteye_node_type == 'elastic_only' ]]; then
        install_perl_dependencies
        exit 0
    fi
    if [[ $neteye_node_type == 'voting_only' ]]; then
        exit 0
    fi
fi
if [[ $neteye_deployment == 'satellite' ]]; then
    install_perl_dependencies
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255