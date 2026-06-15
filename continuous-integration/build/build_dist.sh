#!/usr/bin/env bash

# shellcheck source=./common.sh
# $1 can be passed as -d to activate debugging
. ./continuous-integration/build/common.sh "$1"

# Check if source is to exclude
function check_excludes {
    FILE=$1
    for i in $SOURCE_FILES_EXCLUDES; do
        if [ "$FILE" == "$i" ]; then
            return 0
        fi
    done
    return 1
}

if [[ "$PRESERVE_CVS" == "true" ]]; then
    EXCLUDECVS=""
else
    EXCLUDECVS="--exclude-vcs"
fi

if [ "$EXTERNAL_PROJECT" == "true" ]; then
    #grep the project version from spec file
    parent_project_version=$(grep "%define ${PROJECT_ALIAS}_version" "$SPEC_FILE" | awk '{ print $3 }')

    # download each SourceX in spec file
    log "[i] downloading sources..."
    grep Source "$SPEC_FILE" | cut -d' ' -f2 | while IFS= read -r s; do
        if check_excludes "$s"; then continue; fi
        s=${s//\%\{${PROJECT_ALIAS}_version\}/$parent_project_version}
        wget $quiet_mode "$DOWNLOAD_URL/$s" -O "$SOURCE_PATH/$s"
        RET=$?
        if [ "$RET" -ne "0" ]; then
            log "[-] ERROR downloading $s\n"
            exit 1
        fi
    done
    log " done\n"

    # download each PatchX in spec file
    log "[i] downloading patches..."
    grep Patch "$SPEC_FILE" | cut -d' ' -f2 | while IFS= read -r p; do
        if check_excludes "$p"; then continue; fi
        wget $quiet_mode "$DOWNLOAD_URL/patches/$p" -O "$SOURCE_PATH/$p"
        RET=$?
        if [ "$RET" -ne "0" ]; then
            log "[-] ERROR downloading $p\n"
            exit 1
        fi
    done
    log " done\n" $LOG_INFO

    cd src || exit 1
    svn diff -r2 . >$SOURCE_PATH/thruk-eventcorrections.patch
    cd - || exit 1

    perl ./remove_plugins-enabled_entries_from_patch.pl
    mv $SOURCE_PATH/thruk-eventcorrections.patch2 $SOURCE_PATH/thruk-eventcorrections.patch

    for f in $SOURCE_FILES; do
        log "[i] copying $f\n" $LOG_INFO
        cp "$f" $SOURCE_PATH/
    done

elif [ "$EXTERNAL_PROJECT" == "false" ]; then
    log "[i] Creating tar ..." $LOG_INFO
    tar czf "$SOURCE_PATH/$PROJECT_NAME.tar.gz" \
        $EXCLUDECVS \
        --exclude '.gitignore' \
        --exclude '.gitmodules' \
        --exclude '.settings' \
        --exclude '.buildpath' \
        --exclude '.project' \
        --exclude 'build.sh' \
        --exclude 'build.conf' \
        --exclude 'RPMS' \
        --exclude 'SRPMS' \
        --exclude 'continuous-integration' \
        --exclude '.idea' \
        --exclude 'build_dist.sh' \
        --exclude 'build_rpm.sh' \
        .
    log " done\n" $LOG_INFO

    log "[i] Downloading external sources ..." $LOG_INFO

    # Check if spectool is installed
    if ! type spectool &>/dev/null; then
        log "\n[-] Error: spectool not found. To download external resources you have to install rpmdevtools\n" $LOG_INFO
        exit 2
    fi

    spectool -g -R "$SPEC_FILE" 2>&1 | grep ERROR &>/dev/null
    RET=$?
    if [ $RET -eq 0 ]; then
        log "\n[-] Error downloading external sources\n" $LOG_INFO
        exit 1
    fi
    log " done\n" $LOG_INFO

    if [ -d ./src/patches ]; then
        log "[i] Copying patches from src/patches/ folder ..." $LOG_INFO
        cp ./src/patches/*.patch $SOURCE_PATH
        log " done\n" $LOG_INFO
    fi

    if [ -d ./src/sources ]; then
        log "[i] Copying sources from src/sources/ folder ..." $LOG_INFO
        cp ./src/sources/* $SOURCE_PATH
        log " done\n" $LOG_INFO
    fi
fi