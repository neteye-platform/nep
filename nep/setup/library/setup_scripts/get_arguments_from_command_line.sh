#!/usr/bin/env bash

#####################################################################
## Check actual arguments and store them into local variables      ##
#-------------------------------------------------------------------#
# Usage:                                                            #
# Pre/Post Setup script should invoke this file with source or '.'. #
# This will automatically execute all the arguments test routines,  #
# and actual arguments will be stored in mnemonic variables.        #
# To see name of the variables, look at the end of this file.       #
#####################################################################

# Function to display usage information
usage() {
  echo "Usage: $0 <dry_run> <operation> <verbosity> <nep_name> <target_nep_version> <current_nep_version> <neteye_deployment> <neteye_node_name> <neteye_node_type> <neteye_tenant_name> <neteye_zone_name>"
  echo ""
  echo "Arguments:"
  echo "  dry_run:             Run in dry mode (1) or not (0)."
  echo "                       Choices: 0, 1"
  echo "  operation:           Operation to perform."
  echo "                       Choices: install, reinstall, reinstall-force, update, uninstall"
  echo "  verbosity:           Verbosity level (0: quiet, 1: normal, 2: verbose, 3: debug)."
  echo "                       Choices: 0, 1, 2, 3"
  echo "  nep_name:            Name of the nep being operated on."
  echo "  target_nep_version:  Target version of the nep."
  echo "  current_nep_version: Current version of the nep, empty if not installed."
  echo "  neteye_deployment:   Type of NetEye deployment, it can be 'cluster', 'satellite' or 'single_node'."
  echo "  neteye_node_name:    Hostname of the NetEye node where the nep is being installed."
  echo "  neteye_node_type:    Type of the current NetEye node (neteye or neteye-agent)."
  echo "                       Choices: 'master', 'node', 'satellite', 'elastic_only', 'voting_only'"
  echo "  neteye_tenant_name:  Name of the NetEye tenant where the nep is being installed."
  echo "                       It will be == 'master' on all node types except satellite."
  echo "                       If /etc/neteye-tenant doesn't exist on the satellite, it will be UNAVAILABLE."
  echo "  neteye_zone_name:    The name of the zone. It will be == 'master' on all node types except satellite."
  exit 1
}

# Common functions for error messages
function wrong_deployemnt_type() {
    echo "[!] Wrong Node Type: Node of type '$neteye_node_type' cannot have Deployment of type '$neteye_deployment'"
    exit 1
}

function unsupported_operation() {
    echo "[!] Unsupported Operation: '$operation'"
    exit 1
}

function unsupported_deployment() {
    echo "[!] Unsupported Neteye Deployment: '$neteye_deployment'"
    exit 1
}

function unsupported_node_type() {
    echo "[!] Unsupported Neteye Node Type: '$neteye_node_type'"
    exit 1
}

# Check arguments validity
function check_arguments() {
    # Allow only supported values for enumerative arguments
    if [[ $operation != 'install' && $operation != 'reinstall' && $operation != 'reinstall-force' && $operation != 'update' && $operation != 'uninstall' ]]; then
        unsupported_operation
    fi
    if [[ $neteye_deployment != 'single_node' && $neteye_deployment != 'cluster' && $neteye_deployment !=  'satellite' ]]; then
        unsupported_deployment
    fi
    if [[ $neteye_node_type != 'master' && $neteye_node_type != 'node' && $neteye_node_type != 'satellite' && $neteye_node_type != 'elastic_only' && $neteye_node_type != 'voting_only' && $neteye_node_type != 'single_node' ]]; then
        unsupported_node_type
    fi

    # For single nodes, only Node Type master is allowed
    if [[ $neteye_deployment == 'single_node' ]]; then
        if [[ $neteye_node_type != 'single_node' ]]; then
            wrong_deployemnt_type
        fi
    fi

    # In case of Clusters, only node type Satellite is not allowed
    if [[ $neteye_deployment == 'cluster' ]]; then
        if [[ $neteye_node_type == 'master' || $neteye_node_type == 'satellite' ]]; then
            wrong_deployemnt_type
        fi
    fi

    # If deployment is Satellite, only Satellite as Node Type is allowed
    if [[ $neteye_deployment == 'satellite' ]]; then
        if [[ $neteye_node_type != 'satellite' ]]; then
            wrong_deployemnt_type
        fi
    fi
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 11 ]; then
  usage
fi

# Assign arguments to variables and check their integrity
dry_run=$1
operation=$2
verbosity=$3
nep_name=$4
target_nep_version=$5
current_nep_version=$6
neteye_deployment=$7
neteye_node_name=$8
neteye_node_type=$9
neteye_tenant_name=${10}
neteye_zone_name=${11}
check_arguments
