#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Crypto++ library from sources.

CRYPTOPP_ZIP=cryptopp820.zip
CRYPTOPP_DIR=cryptopp820
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

echo
echo "********** Crypto++ **********"
echo

if ! "$WGET" -O "$CRYPTOPP_ZIP" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://www.cryptopp.com/$CRYPTOPP_ZIP"
then
    echo "Failed to download Crypto++"
    exit 1
fi

rm -rf "$CRYPTOPP_DIR" &>/dev/null
unzip -aoq "$CRYPTOPP_ZIP" -d "$CRYPTOPP_DIR"
cd "$CRYPTOPP_DIR"

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("all" "-j" "$INSTX_JOBS")
if ! CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
     CFLAGS="${BUILD_CFLAGS[*]}" \
     CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
     LDFLAGS="${BUILD_LDFLAGS[*]}" \
     LIBS="${BUILD_LIBS[*]}" \
     "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Crypto++"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

if ! ./cryptest.exe v
then
    echo "Failed to test Crypto++"
    exit 1
fi

if ! ./cryptest.exe tv all
then
    echo "Failed to test Crypto++"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Crypto++"
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

# Test from install directory
if ! "$INSTX_PREFIX/bin/cryptest.exe" v
then
    echo "Failed to test Crypto++"
    exit 1
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

    ARTIFACTS=("$CRYPTOPP_ZIP" "$CRYPTOPP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-cryptopp.sh 2>&1 | tee build-cryptopp.log
    if [[ -e build-cryptopp.log ]]; then
        rm -f build-cryptopp.log
    fi
fi

exit 0
