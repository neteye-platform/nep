#!/usr/bin/env bash
################################################################################
# Grafana Panel Binder - NEP Post-Setup Script
#
# DESCRIPTION:
#   Automatically links Grafana dashboard configurations from a source Icinga
#   command to a target command by cloning sections in graphs.ini.
#
#   This script is part of NEP post-setup automation and should be executed
#   after `reimport_grafana_panes.sh` to ensure all base dashboards are
#   available in graphs.ini before linking operations begin.
#
# DEPENDENCIES:
#   - setup/library/setup_scripts/get_arguments_from_command_line.sh
#   - setup/library/setup_scripts/command_grafana_panel_binder.py
#
# EXIT CODES:
#   0   - Success: All applicable dashboard linking completed
#   255 - Fatal: Invalid deployment configuration detected
#
################################################################################


# === SETUP AND INITIALIZATION ===

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh

################################################################################
# VARIABLE DECLARATIONS
################################################################################
# Path to the Python script that performs the actual dashboard cloning
PYTHON_SCRIPT="${SETUP_LIBRARY}/setup_scripts/command_grafana_panel_binder.py"

# Source command configuration
# Must be an existing command in graphs.ini with a configured Grafana dashboard
# This command serves as the template for dashboard configuration
SOURCE_COMMAND="nx-c-dummy-service"

# Target command configuration
# The Icinga command that will receive the cloned dashboard configuration
# This command's section will be created/updated in graphs.ini
TARGET_COMMAND="nx-c-check-uptime"

# Path to the Grafana graphs.ini configuration file
# Location where Icinga commands are linked to Grafana dashboards
# Default NetEye path for graphs.ini
GRAPHS_INI="/neteye/shared/icingaweb2/conf/modules/grafana/graphs.ini"


################################################################################
# MAIN FUNCTION: bind_grafana_panels
################################################################################

##
# Clone Grafana dashboard configuration from source to target command.
#
# DESCRIPTION:
#   Invokes the Python dashboard binder script with predefined arguments to
#   copy the Grafana dashboard configuration from SOURCE_COMMAND to TARGET_COMMAND.
#   The configuration is read from and written to the graphs.ini file.
#
#
# BEHAVIOR:
#   - Copies all dashboard configuration from SOURCE_COMMAND section to TARGET_COMMAND
#   - Uses --update flag to overwrite existing TARGET_COMMAND configuration if present
#   - All output from Python script is passed through to caller
#   - Function exits with same code as Python script
#
# EXAMPLE:
#   # Simple usage with predefined globals
#   SOURCE_COMMAND="check-memory"
#   TARGET_COMMAND="my-memory-check"
#   bind_grafana_panels
#
#   # Multiple dashboard linking (link different templates)
#   SOURCE_COMMAND="check-memory" && TARGET_COMMAND="cmd1" && bind_grafana_panels
#   SOURCE_COMMAND="check-disk" && TARGET_COMMAND="cmd2" && bind_grafana_panels
#

function bind_grafana_panels() {
    # Execute Python script with arguments
    # --copy-from     : Source command to clone from
    # --command       : Target command to create/update
    # --graphs        : Path to graphs.ini file
    # --update        : Allow overwriting existing target section
    "python3" "$PYTHON_SCRIPT" \
    --copy-from "$SOURCE_COMMAND" \
    --command "$TARGET_COMMAND" \
    --graphs "$GRAPHS_INI" \
    --update
}


if [[ $neteye_deployment == 'single_node' ]]; then
    bind_grafana_panels
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        bind_grafana_panels
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