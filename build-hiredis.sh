#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Hiredis from sources.

HIREDIS_TAR=v0.14.0.tar.gz
HIREDIS_DIR=hiredis-0.14.0
PKG_NAME=hidredis

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

if ! ./build-expat.sh
then
    echo "Failed to build Expat"
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
echo "********** Hiredis **********"
echo

"$WGET" --ca-certificate="$DIGICERT_ROOT" "https://github.com/redis/hiredis/archive/$HIREDIS_TAR" -O "$HIREDIS_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download Hiredis"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$HIREDIS_DIR" &>/dev/null
gzip -d < "$HIREDIS_TAR" | tar xf -
cd "$HIREDIS_DIR"

cp ../patch/hiredis.patch .
patch -u -p0 < hiredis.patch
echo ""

    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
"$MAKE" "-f" "Makefile" "-j" "$INSTX_JOBS"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to build Hiredis"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# TODO
if false; then
if [[ "$IS_DARWIN" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! DYLD_LIBRARY_PATH="lib/.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test Hidredis"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
elif [[ "$IS_LINUX" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! LD_LIBRARY_PATH="lib/.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test Hidredis"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
else
	MAKE_FLAGS=("check" "V=1")
	if ! "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test Hidredis"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
fi
fi

echo "Searching for errors hidden in log files"
COUNT=$(grep -oIR 'runtime error:' | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Hiredis"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
MAKE_FLAGS+=("PREFIX=$INSTX_PREFIX")
MAKE_FLAGS+=("LIBDIR=$INSTX_LIBDIR")
MAKE_FLAGS+=("PKGLIBDIR=${BUILD_PKGCONFIG[*]}")

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

    ARTIFACTS=("$HIREDIS_TAR" "$HIREDIS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-hidredis.sh 2>&1 | tee build-hidredis.log
    if [[ -e build-hidredis.log ]]; then
        rm -f build-hidredis.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
