#!/usr/bin/env bash

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -n | --neteye)
        NETEYE_MAJOR="$2"
        shift # past argument
        shift # past value
        ;;
    *)                     # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift              # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# shellcheck source=./common.sh
. ./continuous-integration/build/common.sh

# define kernel_version for DRBD build
OPTS=("--define" "kernel_version $(uname -r)")
if [ -n "$NETEYE_MAJOR" ]; then
    OPTS=("${OPTS[@]}" "--define" "_neteye_major $NETEYE_MAJOR")
fi

log "[+] installing build dependencies"
if yum-builddep -v &>/dev/null; then
    # CentOS/RHEL 7
    yum-builddep "$SPEC_FILE" --enablerepo=neteye --enablerepo=neteye-staging --enablerepo=neteye-devel --enablerepo=neteye-extras -y
else
    # RHEL 8
    dnf builddep "$SPEC_FILE" -y --enablerepo=neteye --enablerepo=neteye-staging --enablerepo=neteye-devel --enablerepo=neteye-extras
fi

log "[i] building RPMS ... "

mkdir -p "$LOCAL_DEST_DIR_SRPM"
mkdir -p "$LOCAL_DEST_DIR_RPMS_i386"
mkdir -p "$LOCAL_DEST_DIR_RPMS_x86_64"

# set pipefail such that exit 0 of tee doesn't influence on real exit code
(
    set -o pipefail
    rpmbuild "${OPTS[@]}" -ba "$SPEC_FILE" 2>&1 | tee "$BUILDLOG" 2>&1
)

RET=$?
if [ "$RET" != "0" ]; then
    cat "$BUILDLOG"
    exit 1
fi

log " done\\n"

RPMS=$(grep Wrote: "$BUILDLOG" | cut -d' ' -f2)
rm -rf "${LOCAL_DEST_DIR_SRPM:?}"/* "${LOCAL_DEST_DIR_RPMS_i386:?}"/*
for RPM in $RPMS; do
    if echo "$RPM" | grep 'src\.rpm$' >/dev/null; then
        mv "$RPM" "$LOCAL_DEST_DIR_SRPM"
    elif [ "$(uname -i)" = "x86_64" ]; then
        mv "$RPM" "$LOCAL_DEST_DIR_RPMS_x86_64"
    else
        mv "$RPM" "$LOCAL_DEST_DIR_RPMS_i386"
    fi
done
