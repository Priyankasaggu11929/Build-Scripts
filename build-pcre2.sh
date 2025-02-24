#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds PCRE from sources.

PCRE2_TAR=pcre2-10.33.tar.gz
PCRE2_DIR=pcre2-10.33
PKG_NAME=pcre2

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

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
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

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

echo
echo "********** PCRE2 **********"
echo

if ! "$WGET" -O "$PCRE2_TAR" --ca-certificate="$IDENTRUST_ROOT" \
     "https://ftp.pcre.org/pub/pcre/$PCRE2_TAR"
then
    echo "Failed to download PCRE2"
    exit 1
fi

rm -rf "$PCRE2_DIR" &>/dev/null
gzip -d < "$PCRE2_TAR" | tar xf -
cd "$PCRE2_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --enable-shared \
    --enable-pcre2-8 \
    --enable-pcre2-16 \
    --enable-pcre2-32

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure PCRE2"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build PCRE2"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

# PCRE2 fails one self test on older systems, like Fedora 1
# and Ubuntu 4. Allow the failure but print the result.
if [[ "$IS_LINUX" -ne 0 ]]; then
    MAKE_FLAGS=("check" "V=1")
    if ! "$MAKE" "${MAKE_FLAGS[@]}"
    then
        echo "**********************"
        echo "Failed to test PCRE2"
        echo "**********************"
        # exit 1
    fi
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "**********************"
    echo "Failed to test PCRE2"
    echo "**********************"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$PCRE2_TAR" "$PCRE2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-pcre2.sh 2>&1 | tee build-pcre.log
    if [[ -e build-pcre2.log ]]; then
        rm -f build-pcre2.log
    fi
fi

exit 0
