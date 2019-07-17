#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Cpuid from sources.

CPUID_TAR=cpuid-20180519.src.tar.gz
CPUID_DIR=cpuid-20180519
PKG_NAME=cpuid

###############################################################################

# Bail early
if [[ $(uname -m 2>/dev/null | grep -E -i -c 'i86pc|i.86|amd64|x86_64') -eq 0 ]]
then
    echo "Failed to build cpuid. The program is only valid for x86 platforms."
    exit 1
fi

###############################################################################

CURR_DIR=$(pwd)
function finish {
  cd "$CURR_DIR"
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=4}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./setup-password.sh
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

echo
echo "********** Cpuid **********"
echo

if ! "$WGET" -O "$CPUID_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "http://www.etallen.com/cpuid/$CPUID_TAR"
then
    echo "Failed to download Cpuid"
    exit 1
fi

rm -rf "$CPUID_DIR" &>/dev/null
gzip -d < "$CPUID_TAR" | tar xf -
cd "$CPUID_DIR"

cp ../patch/cpuid.patch .
patch -u -p0 < cpuid.patch
echo ""

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
     CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
     CFLAGS="${BUILD_CFLAGS[*]}" \
     CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
     LDFLAGS="${BUILD_LDFLAGS[*]}" \
     LIBS="${BUILD_LIBS[*]}" \
    "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Cpuid"
    exit 1
fi

#echo "**********************"
#echo "Testing package"
#echo "**********************"

# No make check program
#MAKE_FLAGS=("check")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test Cpuid"
#    exit 1
#fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Cpuid"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "PREFIX=$INSTX_PREFIX" "LIBDIR=$INSTX_LIBDIR")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$CPUID_TAR" "$CPUID_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-cpuid.sh 2>&1 | tee build-cpuid.log
    if [[ -e build-cpuid.log ]]; then
        rm -f build-cpuid.log
    fi
fi

exit 0
