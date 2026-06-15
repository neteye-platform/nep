#! /usr/bin/python3.9

# Trova tutti i prerequisites.ini nel path indicato
# Per ogni prerequisite file:
# - Che sia un config file valido
# - Verifica che sia da migrare (esistono proprietà specifiche)
# - Verifica che NON SIA in formato TOML
# - Rinomina il file esistente in .old
# - Legge il file rinominato
# - Converte il file rinominato in TOML e lo salva con il nome originale

import argparse
import configparser
import logging
import os
import pprint

import toml


# Iterates through the files contained in a given directory, recursively or
# only in the first level. For each file, it returns a tuple containing the
#  name of the file and its path. Allows for easy search by filename.
def get_files_in_path(path, recursive):
    if recursive:
        # Recursive walk in the given directory
        # Gets all items, then returns its name
        contents = os.walk(nep_path)
        for (path, directories, files) in contents:
            for file_name in files:
                yield (file_name, path)
    else:
        # One-level search: get all items in the given directory, then keeps only file names
        for file_name in os.listdir(path):
            file_path = os.path.join(path, file_name)
            if os.path.isfile(file_path):
                yield (file_name, path)


# Iterates through the files named prerequisites.inin in a given path,
# recursively or only in the first level. For each file, it returns a tuple
# containing the name of the file and its path. # Allows for easy search by
# filename.
def get_prerequisite_files(nep_path, recursive):
    for (file_name, path) in get_files_in_path(nep_path, recursive):
        if file_name == 'prerequisites.ini':
            yield os.path.join(path, file_name)


# Get a list of all files named prerequisites.ini in a given path, recursively
# or only in the first level.
def get_prerequisite_files_list(nep_path, recursive):
    list = []
    for file_path in get_prerequisite_files(nep_path, recursive):
        list.append(file_path)

    return list


# Tests if a file is a valid TOML file
def is_toml_file(file_path):
    try:
        config_toml = toml.load(file_path)

    except:
        logging.info('File "' + file_path +
                     '" is not a valid TOML file.')
        return False

    return True


# Tests if a file is a valid NEP Prerequisite file
def is_ini_prerequisite_file(file_path):
    # The idea behind:
    # - First of all, the file must be read as an INI file by ConfigParser
    # - Second, it has to contains the minimum properties that qualifies it as
    #   a NEP Prerequisite file

    config_ini = configparser.ConfigParser()

    try:
        # First: it must be a readable INI file
        config_ini.read(file_path)

        # Second: At minimum, sections NEP, NetEye and NetEyeExtensionPacks must be present
        if config_ini.has_section('NEP') == False:
            raise 'Missing section [NEP]'
        if config_ini.has_section('NetEye') == False:
            raise 'Missing section [NetEye]'
        if config_ini.has_section('NetEye') == False:
            raise 'Missing section [NetEyeExtensionPacks]'

        # Third: checking the existence of some minimum options from both sections
        # NEP must have a name and a version
        # NetEye must have a minversion and a modules list
        # NeytEyeExtensionPacks can be empty
        if config_ini.has_option('NEP', 'name') == False:
            raise 'Missing option "name" from section [NEP]'
        if config_ini.has_option('NEP', 'version') == False:
            raise 'Missing option "version" from section [NEP]'

        if config_ini.has_option('NetEye', 'minversion') == False:
            raise 'Missing option "minversion" from section [NetEye]'
        if config_ini.has_option('NetEye', 'modules') == False:
            raise 'Missing option "modules" from section [NetEye]'

    except:
        logging.info('File "' + file_path +
                     '" is not a valid INI Prerequisite file.')
        return False

    return True


# Converts section NEP from INI to the nep_setup format
def convert_section_nep(config_ini):
    # Property version should be written in a MAJOR.MINOR.REVISION format.
    # By default, MAJOR and MINOR will be set to 0
    # All other properties will be left intact
    converted = {}
    for option_name in config_ini.options('NEP'):
        option_value = config_ini['NEP'][option_name]
        if option_name == 'version':
            option_value = '0.0.' + option_value

        converted[option_name] = option_value

    return converted


# Converts section NetEye from INI to the nep_setup format
def convert_section_neteye(config_ini):
    # Property minversion must become version and be expressed as a range,
    # using MAJOR.MINOR.REVISION format. By default, MAJOR and MINOR will be
    # set to 0 and range is >=.
    # All other properties will be left intact
    converted = {}
    for option_name in config_ini.options('NetEye'):
        option_value = config_ini['NetEye'][option_name]
        if option_name == 'minversion':
            option_name = 'version'
            option_value = '>=' + option_value



        converted[option_name] = option_value

    return converted


# Converts section NetEyeExtensionPacks from INI to the nep_setup format
def convert_section_neteyeextensionpacks(config_ini):
    # Each property contains the minimum required version of another NEP.
    # This version should be expressed as a range, using MAJOR.MINOR.REVISION
    # format. By default, MAJOR and MINOR will be set to 0 and range is >=.
    # No other properties are allowed.
    converted = {}
    for option_name in config_ini.options('NetEyeExtensionPacks'):
        option_value = '>=0.0.' + \
            config_ini['NetEyeExtensionPacks'][option_name]

        converted[option_name] = option_value

    return converted


# Converts a generic section from INI to the nep_setup format
def convert_section(config_ini, section_name):
    # Properties are just copied as they are
    converted = {}
    for option_name in config_ini.options(section_name):
        converted[option_name] = config_ini[section_name][option_name]

    return converted


# Converts data from a NEP Prerequisites file into the new nep-setup format,
# then saves it as a TOML file.
def test_and_convert_to_toml(ini_file_path, backup_file_suffix, dry_run):
    # Read and convert the original configuration
    with open(ini_file_path, 'r') as config_ini:
        ini_config_string = config_ini.read()
        logging.debug('INI configuration:\n' + ini_config_string)

    source_config = configparser.ConfigParser()
    source_config.read(ini_file_path)

    converted_config = {}

    for section_name in source_config.sections():
        logging.debug('Converting section "' + section_name + '"')
        if section_name == 'NEP':
            converted_section = convert_section_nep(source_config)
        elif section_name == 'NetEye':
            converted_section = convert_section_neteye(source_config)
        elif section_name == 'NetEyeExtensionPacks':
            converted_section = convert_section_neteyeextensionpacks(source_config)
        else:
            converted_section = convert_section(source_config, section_name)

        converted_config[section_name] = converted_section

    converted_config_string = pprint.pformat(converted_config)
    logging.debug('Converted configuration:\n' + converted_config_string)

    # Rename the original file, to have a backup
    backup_file_path = ini_file_path + backup_file_suffix
    logging.info('Renaming original INI file to ' + backup_file_path)
    if dry_run == False:
        os.rename(ini_file_path, backup_file_path)

    # Stores the converted configuration in TOML format
    logging.info('Dumping TOML configuration to ' + ini_file_path)
    if dry_run == False:
        with open(ini_file_path, 'w') as config_toml:
            toml_config_string = toml.dump(converted_config, config_toml)
    else:
        toml_config_string = toml.dumps(converted_config)

    logging.debug('TOML configuration:\n' + toml_config_string)

    logging.info('Done')


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Migrate a INI NEP Prerequisite file to new nep-setup format (TOML-based).')
    parser.add_argument('-p', '--nep-path', required=True, action='store', dest='nep_path',
                        default='./', help='Path containing NEP Package to check and convert')
    parser.add_argument('-s', '--backup-suffix', required=False, action='store', dest='backup_suffix',
                        default='.bkp', help='Suffix for the backup file name')
    parser.add_argument('-r', '--recursive',  required=False, action='store_true', dest='recursive',
                        help='Look for prerequsite files into all subdirectories')
    parser.add_argument('-d', '--dry-run',  required=False, action='store_true', dest='dry_run',
                        help='Performs a dry run')
    parser.add_argument('-v', '--verbose', required=False, action='count',
                        dest='verbose_count', default=0, help='Enable verbose/debug logging')

    #arguments = parser.parse_args(['-p', '/neteye/shared/nep/data', '-vvv', '-r' ])
    arguments = parser.parse_args()

    return arguments


def set_log_level(log_level_count):
    # Setting log level for this script. Default is WARNING or above.
    # If by command line one or more verbose are specified, log level is updated accordingly
    log_level = logging.WARNING
    if log_level_count == 0:
        log_level = logging.WARNING
    if log_level_count == 1:
        log_level = logging.INFO
    if log_level_count > 1:
        log_level = logging.DEBUG
        logging.basicConfig(
            level=log_level, format='[%(asctime)s][%(levelname)-8s] %(message)s')


def convert_to_toml(nep_path, backup_suffix, recursive, dry_run = True):
    if dry_run:
        logging.warn('PERFORMING A DRY RUN: ENSURE TO SET VERBOSITY TO INFO OR DEBUG')

    if recursive:
        logging.info('Looking for prerequisite files into "' + nep_path + '"')
    else:
        logging.info('Looking for prerequisite files into "' +
                     nep_path + '" and its subfolders')

    file_list = get_prerequisite_files_list(nep_path, recursive)
    if len(file_list) == 0:
        logging.error('No prerequisite files found in ' +
                      nep_path + '. Quitting.')
        exit(1)

    logging.debug('Prerequisite files found:')
    for file in file_list:
        logging.debug('- ' + file)

    for file in file_list:
        logging.info('Processing file "' + file + '"')
        if is_toml_file(file):
            logging.info('File ' + file + ' is a TOML file. Skipping.')
        else:
            test_and_convert_to_toml(file, backup_suffix, dry_run)


if __name__ == '__main__':
    arguments = parse_arguments()

    nep_path = arguments.nep_path
    backup_suffix = arguments.backup_suffix
    recursive = arguments.recursive
    dry_run = arguments.dry_run
    log_level_count = arguments.verbose_count

    set_log_level(log_level_count)

    logging.debug('Command line arguments:')
    logging.debug('- NEP Path     : ' + nep_path)
    logging.debug('- Backup suffix: ' + backup_suffix)
    logging.debug('- Recursive    : ' + str(recursive))
    logging.debug('- Dry run      : ' + str(dry_run))

    convert_to_toml(nep_path, backup_suffix, recursive, dry_run)
