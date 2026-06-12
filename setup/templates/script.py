#!/usr/bin/env python3
import argparse

# Define the arguments
parser = argparse.ArgumentParser(description="Pre-setup script for the project.")
parser.add_argument(
    "dry_run",
    choices=[0, 1],
    help="Run in dry mode (1) or not (0).",
)
parser.add_argument(
    "operation",
    choices=["install", "reinstall", "reinstall-force", "uninstall"],
    help="Operation to perform.",
)
parser.add_argument(
    "verbosity",
    choices=[0, 1, 2, 3],
    help="Verbosity level (0: quiet, 1: normal, 2: verbose, 3: debug).",
)
parser.add_argument(
    "nep_name",
    type=str,
    help="Name of the nep being operated on.",
)
parser.add_argument(
    "target_nep_version",
    type=str,
    help="Target version of the nep.",
)
parser.add_argument(
    "current_nep_version",
    type=str,
    help="Current version of the nep, empty if not installed.",
)
parser.add_argument(
    "neteye_deployment",
    choices=["cluster", "satellite", "single_node"],
    type=str,
    help="hostname of the NetEye node where the nep is being installed.",
)
parser.add_argument(
    "neteye_node_name",
    help="hostname of the NetEye node where the nep is being installed.",
)
parser.add_argument(
    "neteye_node_type",
    choices=["master", "node", "satellite", "elastic_only", "voting_only", "single_node"],
    help="Type of the current NetEye node (neteye or neteye-agent).",
)
parser.add_argument(
    "neteye_tenant_name",
    type=str,
    help="""
    Name of the NetEye tenant where the nep is being installed.
    It will be == 'master' on all node types except satellite.
    If `/etc/neteye-tenant` doesn't exists on the satellite, it will be `UNAVAILABLE`.
    """,
)
parser.add_argument(
    "neteye_zone_name",
    type=str,
    help="The name of the zone. It will be == 'master' on all node types except satellite.",
)

# Parse the arguments from argv
args = parser.parse_args()

# Extract into variables
dry_run = bool(int(args.dry_run))
operation = args.operation
verbosity = int(args.verbosity)
nep_name = args.nep_name
target_nep_version = args.target_nep_version
current_nep_version = args.current_nep_version
neteye_node_name = args.neteye_node_name
neteye_node_type = args.neteye_node_type
neteye_tenant_name = args.neteye_tenant_name
neteye_zone_name = args.neteye_zone_name