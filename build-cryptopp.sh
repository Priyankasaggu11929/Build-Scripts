#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Crypto++ library from sources.

CRYPTOPP_TAR=CRYPTOPP_8_0_0.tar.gz
CRYPTOPP_DIR=CRYPTOPP_8_0_0
PKG_NAME=cryptopp

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
    source ./build-password.sh
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** Crypto++ **********"
echo

"$WGET" --ca-certificate="$DIGICERT_ROOT" "https://github.com/weidai11/cryptopp/archive/$CRYPTOPP_TAR" -O "$CRYPTOPP_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download Crypto++"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$CRYPTOPP_DIR" &>/dev/null
gzip -d < "$CRYPTOPP_TAR" | tar xf -
mv "cryptopp-$CRYPTOPP_DIR" "$CRYPTOPP_DIR"
cd "$CRYPTOPP_DIR"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "all")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Crypto++"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if ! ./cryptest.exe v
then
    echo "Failed to test Crypto++"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# OK to uncomment, commented for expediency
# if ! ./cryptest.exe tv all
# then
#     echo "Failed to test Crypto++"
#     [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
# fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Test from install directory
if ! "$INSTX_PREFIX/bin/cryptest.exe" v
then
    echo "Failed to test Crypto++"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$CRYPTOPP_TAR" "$CRYPTOPP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-cryptopp.sh 2>&1 | tee build-cryptopp.log
    if [[ -e build-cryptopp.log ]]; then
        rm -f build-cryptopp.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
