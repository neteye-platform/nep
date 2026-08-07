#!/usr/bin/python3
"""
Feat: NEP-901 Link existing Grafana Panels to other Commands
Script that generate an entry in graphs.ini for a new command using as base one command with an existing Grafana Panel.

To test script locally
# Single command (works exactly as before)
uv run python command_grafana_panel_binder.py --copy-from ssh --command my_command --graphs test/data/graphs.ini

# Multiple commands
uv run python command_grafana_panel_binder.py --copy-from ssh --command cmd1 cmd2 cmd3 --graphs test/data/graphs.ini -v

# Dry run with multiple targets
uv run python command_grafana_panel_binder.py --copy-from hostalive --command check-disk check-memory check-cpu --graphs test/data/graphs.ini --dry-run

"""

import argparse
import configparser
import os
import sys
import logging
logger = logging.getLogger(__name__)

GRAPHS_INI_DEFAULT = "/neteye/shared/icingaweb2/conf/modules/grafana/graphs.ini"

def load_graphs_ini(graphs_path):
    """Load and parse graphs.ini"""
    logging.debug('load graphs.ini')

    config = configparser.ConfigParser()
    config.optionxform = str # Do not normalize keys to lowercase
    
    if os.path.isfile(graphs_path):
        config.read(graphs_path)
    return config



def bind_target_to_source(config, source_cmd, target_cmd, update=True, dry_run=False):
    """
    Clone the source_cmd section and change the title to target_cmd,
    then insert or update the target_cmd in the config.

    Returns:
        (config, errors)
    """
    section_removed = []
    section_added = []
    errors = []


    # Validate source section exists
    if not config.has_section(source_cmd):
        errors.append(f"Source section [{source_cmd}] not found in graphs.ini.")
        return config, errors

    # Remove existing target section if updating
    if config.has_section(target_cmd) and update:
        config.remove_section(target_cmd)
        section_removed.append(target_cmd)
        logging.info(f"Removed existing section [{target_cmd}]")
    elif config.has_section(target_cmd):
        errors.append(
            f"Target section [{target_cmd}] already exists. "
            "Use --update to overwrite it."
        )
        return config, errors
    else:
        logging.info(f"[{target_cmd}] section does not exists.")

    # Copy all key-value pairs from source to target
    source_items = dict(config[source_cmd])

    # Create target section in config
    config.add_section(target_cmd)
    for key, value in source_items.items():
        config.set(target_cmd, key, value)

    section_added.append(target_cmd)
    logging.info(f"Added section [{target_cmd}] with {len(source_items)} key(s)")

    # recap
    if section_removed:
        logger.info(f"[-] Removed section(s):")
        for s in section_removed:
            logger.info(f"    [{s}]")

    if section_added:
        logger.info(f"[+] Added section(s):")
        for s in section_added:
            logger.info(f"    [{s}]")
            for key, val in config[s].items():
                logger.debug(f"        {key} = {val}")

    if errors:
        print(f"\n[!] Errors ({len(errors)}):")
        for e in errors:
            logger.error(f"    {e}")

    return config, errors

def save_graphs_ini(config, graphs_path):
    """Save graphs.ini."""
    with open(graphs_path, "w") as f:
        config.write(f)



def main():
    # === args === #
    parser = argparse.ArgumentParser(
        description="Link existing Grafana Panel to a Command"
    )
    parser.add_argument(
        "--copy-from",
        required=True,
        help=f"Existing Command name with Grafana Dashboard (examples: [hostalive, check-memory, nscp-local-disk])",
    )
    parser.add_argument(
        "--command",
        required=True,
        nargs="+",
        metavar="COMMAND",
        help="One or more commands to be linked to the existing Grafana Dashboard",
    )
    parser.add_argument(
        "--graphs",
        default=GRAPHS_INI_DEFAULT,
        help=f"Path to graphs.ini (default: {GRAPHS_INI_DEFAULT})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without writing changes",
    )
    parser.add_argument(
        "-u", "--update",
        action="store_true",
        default=True,
        help="Allow update of existing commmand in graphs.ini",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Show detailed output",
    )


    args = parser.parse_args()

    if (args.verbose):
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)
    logging.debug(f"args: {args}")

    if args.dry_run:
        logging.warning("Running in DRY RUN MODE — no changes will be written.")

    logging.info(f"Source command:      {args.copy_from}")
    logging.info(f"Destination command: {args.command}")

    # === Load graphs.ini === #
    logging.info(f"Loading graphs.ini: {args.graphs}")
    config = load_graphs_ini(args.graphs)
    logging.info(f"Found {len(config.sections())} existing section(s)")
    for item in config.items():
        logging.debug(item)

    # === Apply bindings for each target command === #
    all_errors = []
    for target_cmd in args.command:
        logging.info(f"--- Binding [{args.copy_from}] → [{target_cmd}] ---")
        config, errors = bind_target_to_source(
            config,
            args.copy_from,
            target_cmd,
            args.update,
            args.dry_run,
        )
        all_errors.extend(errors)

    # === Save === #
    if not errors and not args.dry_run:
        save_graphs_ini(config, args.graphs)
        logger.info(f"Saved to {args.graphs}")
    elif args.dry_run:
        logger.info(f"Dry run - no changes written.")

    # === Exit code === #
    if errors:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
