#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds LDNS from sources.

LDNS_DIR=ldns-master
LDNS_TAG=release-1.7.0
PKG_NAME=ldns

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
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./setup-password.sh
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-unbound.sh
then
    echo "Failed to build Unbound"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** LDNS **********"
echo

rm -rf "$LDNS_DIR" &>/dev/null

if ! git clone https://github.com/NLnetLabs/ldns.git "$LDNS_DIR"
then
    echo "Failed to clone LDNS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

cd "$LDNS_DIR"
git checkout "$LDNS_TAG" &>/dev/null

if [[ "$IS_OLD_DARWIN" -ne 0 ]]
then
    cp ../patch/ldns-darwin.patch .
    patch -u -p0 < ldns-darwin.patch
    echo ""
fi

if ! autoreconf --force --install && libtoolize --force
then
    echo "Failed to autoreconf LDNS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

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
    --with-ssl="$INSTX_PREFIX" \
    --with-ca-file="$SH_UNBOUND_CACERT_FILE" \
    --with-ca-path="$SH_UNBOUND_CACERT_PATH" \
    --with-trust-anchor="$SH_UNBOUND_ROOTKEY_FILE" \
    --disable-dane-ta-usage

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure LDNS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build LDNS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

# 'make test' fails for 1.7.0
MAKE_FLAGS=("test")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test LDNS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(grep -oIR 'runtime error:' ./* | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test LDNS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
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

    ARTIFACTS=("$LDNS_TAR" "$LDNS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-ldns.sh 2>&1 | tee build-ldns.log
    if [[ -e build-ldns.log ]]; then
        rm -f build-ldns.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
