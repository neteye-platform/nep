#!/usr/bin/env bash

# shellcheck source=./build_default.conf
. ./continuous-integration/build/build_default.conf # values in build.conf will overwrite build_default.conf values
# shellcheck disable=SC1091
. ./build.conf

# Do this only if we are in Jenkins
if [ -n "$BUILD_RELEASE" ]; then
    export NETEYE_RELEASE=$BUILD_RELEASE
else
    export NETEYE_RELEASE=$NETEYE_RELEASE_STABLE
fi

if [ -z "$SPEC_FILE" ]; then
    SPEC_FILE=${PROJECT_NAME}.spec
fi

export BUILDLOG=/tmp/.$PROJECT_NAME-build.log
DOWNLOAD_URL=$DOWNLOAD_URL/$PROJECT_NAME

export LOG_INFO=1

# Set source path
if [ -d /usr/src/redhat/SOURCES/ ]; then
    SOURCE_PATH=/usr/src/redhat/SOURCES
else
    SOURCE_PATH=~/rpmbuild/SOURCES
    mkdir -p $SOURCE_PATH
fi

# Logging
export quiet_mode="-q" # Used in ssh/scp/svn commands
log_level=1
if [[ -n $1 ]]; then
    if [[ $1 == "-q" ]]; then
        log_level=0
    elif [[ $1 == "-d" ]]; then
        log_level=2
        quiet_mode="" # Removes quiet flag from commands
    fi
fi

function log {
    message=$1
    message_level=$2
    if [ -z "$message" ]; then
        echo "Usage: log \"message\" [0-2]"
        exit 1
    fi
    if [ -z "$message_level" ]; then message_level=1; fi

    if [[ $log_level -ge $message_level ]]; then printf "%s" "$message"; fi
}

function getSpecVar {
    sed -n "s/%define $1 \(.\+\)/\1/p" "$SPEC_FILE"
}

function linkSrc {
    SRC=$1
    DST=$2
    if [ -h "$DST" ]; then
        echo "[-] LINK EXISTS: ($SRC -> $DST). skipping"
        return 1
    elif [ -e "$SRC" ]; then
        if [[ -e "$DST" && ! -e ${DST}.bak ]]; then
            mv "$DST" "${DST}.bak"
        elif [ -e "${DST}.bak" ]; then
            echo "[-] BAK EXISTS: ($SRC -> $DST). skipping"
            return 2
        fi
        ln -s "$SRC" "$DST"
    fi
}

function is_alpha_build() {
    [[ "$JOB_NAME" =~ [aA]lpha ]]
}

function is_staging_build() {
    [[ "$JOB_NAME" =~ [sS]taging ]]
}

function is_beta_build() {
    [[ "$JOB_NAME" =~ [bB]eta ]]
}

function is_provisioning_build() {
    [[ "$JOB_NAME" =~ NetEye-Cluster-Provisioning* ]]
}