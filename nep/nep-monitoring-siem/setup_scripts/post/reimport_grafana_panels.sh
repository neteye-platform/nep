#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################

function import_grafana_panels() {
    SECURE_INSTALL_VARDIR=/neteye/shared/secure_install/
    . /usr/share/neteye/grafana/scripts/grafana_autosetup_functions.sh
    . /usr/share/neteye/secure_install/481_01_icingaweb2-module-grafana_install_template_dashboards_autosetup.sh
    . /usr/share/neteye/secure_install/481_03_icingaweb2-module-grafana_configure_graph_mapping.sh
}


if [[ $neteye_deployment == 'single_node' ]]; then
    import_grafana_panels
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        import_grafana_panels
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