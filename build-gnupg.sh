#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GnuPG and its dependencies from sources.

GNUPG_TAR=gnupg-2.2.12.tar.bz2
GNUPG_DIR=gnupg-2.2.12
PKG_NAME=gnupg

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

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

if ! ./build-gpgerror.sh
then
    echo "Failed to build Libgerror"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-libgcrypt.sh
then
    echo "Failed to build Libgcrypt"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-libksba.sh
then
    echo "Failed to build Libksba"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-libassuan.sh
then
    echo "Failed to build Libassuan"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-ntbTLS.sh
then
    echo "Failed to build ntbTLS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-nPth.sh
then
    echo "Failed to build nPth"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** GnuPG **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://gnupg.org/ftp/gcrypt/gnupg/$GNUPG_TAR" -O "$GNUPG_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download GnuPG"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$GNUPG_DIR" &>/dev/null
tar xjf "$GNUPG_TAR"
cd "$GNUPG_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

# Solaris is a tab bit stricter than libc
#if [[ "$IS_SOLARIS" -eq "1" ]]; then
#    # Don't use CPPFLAGS. _XOPEN_SOURCE will cross-pollinate into CXXFLAGS.
#    BUILD_CFLAGS+=("-D_XOPEN_SOURCE=600 -std=c99")
#    BUILD_CXXFLAGS+=("-std=c++03")
#fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure GnuPG"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

cd "tests/gpgscm"
cp ../../../gnupg.patch .
patch < gnupg.patch
cd "../.."

MAKE_FLAGS=("-j" "$INSTX_JOBS" "all")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GnuPG"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test GnuPG"
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

    ARTIFACTS=("$GNUPG_TAR" "$GNUPG_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-gnupg.sh 2>&1 | tee build-gnupg.log
    if [[ -e build-gnupg.log ]]; then
        rm -f build-gnupg.log
    fi

    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
