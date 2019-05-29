#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Bzip2 from sources.

# Bzip lost its website. This build of Bzip is based on the last known
# release bzip-1.0.6. Also see https://github.com/noloader/bzip2-noloader.

BZIP2_TAR=BZIP2_1_0_6_1.tar.gz
BZIP2_DIR=BZIP2_1_0_6_1
PKG_NAME=bzip2

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

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
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

echo
echo "********** Bzip **********"
echo

# https://github.com/noloader/bzip2-noloader/archive/BZIP2_1_0_6_1.tar.gz

if ! "$WGET" -O "$BZIP2_TAR" --ca-certificate="$DIGICERT_ROOT" \
     "https://github.com/noloader/bzip2-noloader/archive/$BZIP2_TAR"
then
    echo "Failed to download Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$BZIP2_DIR" &>/dev/null
gzip -d < "$BZIP2_TAR" | tar xf -
mv "bzip2-noloader-${BZIP2_DIR}" "${BZIP2_DIR}"
cd "$BZIP2_DIR"

cp ../patch/bzip2.patch .
patch -u -p0 < bzip2.patch
echo ""

# Fix format specifier.
# TODO: fix this in the source code.
if [[ "$IS_64BIT" -ne 0 ]]; then
    for cfile in $(find "$PWD" -name '*.c'); do
        sed -e "s|%Lu|%llu|g" "$cfile" > "$cfile.fixed"
        mv "$cfile.fixed" "$cfile"
    done
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! CC="${CC}" CFLAGS="${BUILD_CFLAGS[*]}" "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check")
if ! CC="${CC}" CFLAGS="${BUILD_CFLAGS[*]}" "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' | grep -o 'runtime error:' | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=(install "PREFIX=$INSTX_PREFIX" "LIBDIR=$INSTX_LIBDIR")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

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

    ARTIFACTS=("$BZIP2_TAR" "$BZIP2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-bzip.sh 2>&1 | tee build-bzip.log
    if [[ -e build-bzip.log ]]; then
        rm -f build-bzip.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
