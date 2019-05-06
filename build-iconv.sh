#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds iConv from sources.

ICONV_TAR=libiconv-1.16.tar.gz
ICONV_DIR=libiconv-1.16
PKG_NAME=iconv

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

echo
echo "********** iConv **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://ftp.gnu.org/pub/gnu/libiconv/$ICONV_TAR" -O "$ICONV_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$ICONV_DIR" &>/dev/null
gzip -d < "$ICONV_TAR" | tar xf -
cd "$ICONV_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --enable-shared --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ "$IS_DARWIN" -ne 0 ]];
then
    MAKE_FLAGS=("check" "V=1")
    if ! DYLD_LIBRARY_PATH="lib/.libs" "$MAKE" "${MAKE_FLAGS[@]}"
    then
        echo "Failed to test iConv"
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
elif [[ "$IS_LINUX" -ne 0 ]];
then
    MAKE_FLAGS=("check" "V=1")
    if ! LD_LIBRARY_PATH="lib/.libs" "$MAKE" "${MAKE_FLAGS[@]}"
    then
        echo "Failed to test iConv"
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
else
    MAKE_FLAGS=("check" "V=1")
    if ! "$MAKE" "${MAKE_FLAGS[@]}"
    then
        echo "Failed to test iConv"
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

echo "Searching for errors hidden in log files"
COUNT=$(grep -oIR 'runtime error:' ./* | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test iConv"
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

    ARTIFACTS=("$ICONV_TAR" "$ICONV_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-iconv.sh 2>&1 | tee build-iconv.log
    if [[ -e build-iconv.log ]]; then
        rm -f build-iconv.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
