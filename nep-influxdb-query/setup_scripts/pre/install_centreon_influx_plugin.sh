#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
# Install RPM for InfluxDB Centreon Plugin
# At present moment, the only working version is available from the unstable repo

echo "[i] Installing InfluxDB Centreon Plugin"
dnf -y --enablerepo=centreon-*-stable*,epel install centreon-plugin-Applications-Databases-Influxdb

exit $?