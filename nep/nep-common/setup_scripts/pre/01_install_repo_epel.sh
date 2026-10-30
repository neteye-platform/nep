#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
## Install and disabel EPEL Repo
echo "[i] Installing EPEL Repo definitions"
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
if [ $? -eq 0 ]; then
    echo ' Done'
else
    echo ' Failed'
    exit 1
fi

echo "[i] Disabling EPEL Repos enabled by default"
for repo in $(dnf repolist --enabled | grep -e '^epel' | awk '{ print $1 }'); do
    echo -n "  Disabling repo $repo..."
    dnf config-manager --disable $repo > /dev/null
    if [ $? -eq 0 ]; then
        echo ' Done'
    else
        echo ' Failed'
        exit 1
    fi
done

exit 0
