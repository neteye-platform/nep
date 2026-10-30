#! /bin/bash

### NEP Data dir migration process ###########################################
# Old nep-setup keeps a copy on the system of all NEPs that have been i      #
# installed or updated. For the new nep-setup to work, each copy must be     #
# converted into the right format.                                           #
# 1. All prerequisite files must be converted into TOML and updated          #
# 2. The folder structure must reflect the new version naming convention     #
##############################################################################

NEP_DATA_DIR=/neteye/shared/nep/data/packages
NEP_MIGRATION_DIR=/usr/share/neteye/nep/setup/migration

# Convert all prerequisites in TOML format.
# A backup copy is created in the same folder (extension: .bkp)
echo 'Converting prerequisite files of installed NEPs'
${NEP_MIGRATION_DIR}/convert-nep-prerequisite-file.py -p ${NEP_DATA_DIR} -r -v
retval=$?

# If conversion is completed, the directory tree must be migrated
# Locate the folders with the old naming convention, then rename them.
# No backup is created.
if [ $retval == 0 ]; then
    echo 'Done. Converting installed NEP directory tree...'
    for d in $(find ${NEP_DATA_DIR} -maxdepth 2 -mindepth 2 -type d -iname v.*); do
        src=$d
        dst=$(echo $d | sed 'sS/v\.S/0.0.Sg')
        echo "Renaming: $src -> $dst"
        mv "$src" "$dst"
    done

    echo Done
else
    echo "Got return value ${retval}. Unable to continue"
    exit 1
fi