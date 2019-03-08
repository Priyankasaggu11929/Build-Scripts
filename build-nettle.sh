#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Nettle from sources.

NETTLE_TAR=nettle-3.4.1.tar.gz
NETTLE_DIR=nettle-3.4.1
PKG_NAME=nettle

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
if ! source ./build-environ.sh
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
    source ./build-password.sh
fi

###############################################################################

if ! ./build-gmp.sh
then
    echo "Failed to build GMP"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** Nettle **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://ftp.gnu.org/gnu/nettle/$NETTLE_TAR" -O "$NETTLE_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$NETTLE_DIR" &>/dev/null
gzip -d < "$NETTLE_TAR" | tar xf -
cd "$NETTLE_DIR"

cp ../patch/nettle.patch .
patch -u -p0 < nettle.patch

# This works for all versions of Nettle on all Apple platforms
if [[ "$IS_DARWIN" -ne "0" ]]; then
    sed -e 's|LD_LIBRARY_PATH|DYLD_LIBRARY_PATH|g' examples/Makefile.in > examples/Makefile.in.fixed
    mv examples/Makefile.in.fixed examples/Makefile.in
    touch -t 197001010000 examples/Makefile.in

    sed -e 's|LD_LIBRARY_PATH|DYLD_LIBRARY_PATH|g' testsuite/Makefile.in > testsuite/Makefile.in.fixed
    mv testsuite/Makefile.in.fixed testsuite/Makefile.in
    touch -t 197001010000 testsuite/Makefile.in
fi

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

# Awful Solaris 64-bit hack. Rewrite some values
if [[ "$IS_SOLARIS" -eq "1" ]]; then
    # Solaris requires -shared for shared object
    sed 's| -G -h| -shared -h|g' configure.ac > configure.ac.fixed
    mv configure.ac.fixed configure.ac; chmod +x configure.ac
    touch -t 197001010000 configure.ac
fi

# This scares me, but it is necessary...
autoreconf

if [[ "$?" -ne "0" ]]; then
    echo "Failed to reconfigure Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

CONFIG_OPTS=()
CONFIG_OPTS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--disable-documentation")

if [[ "$IS_IA32" -ne "0" ]]; then
    CONFIG_OPTS+=("--enable-fat")
fi

# Awful Solaris 64-bit hack. Rewrite some values
if [[ "$IS_SOLARIS" -eq "1" ]]; then
    # Autotools uses the i386-pc-solaris2.11, which results in 32-bit binaries
    if [[ "$IS_X86_64" -eq "1" ]]; then
        # Fix Autotools mis-detection on Solaris
        CONFIG_OPTS+=("--build=x86_64-pc-solaris2.11")
        CONFIG_OPTS+=("--host=x86_64-pc-solaris2.11")
    fi
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure "${CONFIG_OPTS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(grep -oIR 'runtime error' | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
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

    ARTIFACTS=("$NETTLE_TAR" "$NETTLE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-nettle.sh 2>&1 | tee build-nettle.log
    if [[ -e build-nettle.log ]]; then
        rm -f build-nettle.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
