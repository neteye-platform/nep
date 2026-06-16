#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
# Action scripts are launched by OEC by directly invoking 'python'.
# Since on RHEL8 the default symlink python is not set, it now will be
# forced via alternatives.
function set_python_engine() {
    PYTHON3_ENGINE_PATH=/usr/bin/python3

    echo "Checking default python engine"
    python_alternatives=$(alternatives --list | egrep '^python ')
    alternatives_mode=$(echo ${python_alternatives} | cut -d ' ' -f 2)
    alternatives_path=$(echo ${python_alternatives} | cut -d ' ' -f 3)
    echo "[i] Current mode is \"${alternatives_mode}\""
    echo "[i] Current python engine is \"${alternatives_path}\""

    if [[ "${alternatives_mode}" == "auto" ]]; then
        echo "[i] Current alternative for Python is automatic. Forcing it to Python 3..."
        alternatives --set python ${PYTHON3_ENGINE_PATH}
    else
        echo "[i] Current alternative for Python as been already set. Skipping."
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    set_python_engine
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        set_python_engine
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