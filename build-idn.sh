#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds IDN and IDN2 from sources.

IDN_TAR=libidn-1.35.tar.gz
IDN_DIR=libidn-1.35
PKG_NAME1=libidn

IDN2_TAR=libidn2-2.1.1a.tar.gz
IDN2_DIR=libidn2-2.1.1a
PKG_NAME2=libidn2

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

if [[ -e "$INSTX_CACHE/$PKG_NAME1" && -e "$INSTX_CACHE/$PKG_NAME2" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME1 and $PKG_NAME2 are already installed."
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
echo "********** IDN **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://ftp.gnu.org/gnu/libidn/$IDN_TAR" -O "$IDN_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$IDN_DIR" &>/dev/null
gzip -d < "$IDN_TAR" | tar xf -
cd "$IDN_DIR"

# Avoid reconfiguring.
if [[ ! -e "configure" ]]; then
    ./bootstrap.sh
    if [[ "$?" -ne 0 ]]; then
        echo "Failed to reconfigure IDN"
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

if [[ "$IS_SOLARIS" -eq 1 ]]; then
  if [[ (-f src/idn2.c) ]]; then
    sed -e '/^#include "error.h"/d' src/idn2.c > src/idn2.c.fixed
    mv src/idn2.c.fixed src/idn2.c
    sed -e '43istatic void error (int status, int errnum, const char *format, ...);' src/idn2.c > src/idn2.c.fixed
    mv src/idn2.c.fixed src/idn2.c

    {
      echo ""
      echo "static void"
      echo "error (int status, int errnum, const char *format, ...)"
      echo "{"
      echo "  va_list args;"
      echo "  va_start(args, format);"
      echo "  vfprintf(stderr, format, args);"
      echo "  va_end(args);"
      echo "  exit(status);"
      echo "}"
      echo ""
    } >> src/idn2.c
    touch -t 197001010000 src/idn2.c
  fi
fi

# https://bugs.launchpad.net/ubuntu/+source/binutils/+bug/1340250
if [[ ! -z $(command -v ld) ]]; then
	BUILD_LIBS+=("-Wl,--no-as-needed")
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared \
    --disable-doc

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ "$IS_DARWIN" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! DYLD_LIBRARY_PATH="./.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test IDN"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
elif [[ "$IS_LINUX" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! LD_LIBRARY_PATH="./.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test IDN"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME1"

###############################################################################

echo
echo "********** IDN2 **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://ftp.gnu.org/gnu/libidn/$IDN2_TAR" -O "$IDN2_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download IDN2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$IDN2_DIR" &>/dev/null
gzip -d < "$IDN2_TAR" | tar xf -
cd "$IDN2_DIR"

# Avoid reconfiguring.
if [[ ! -e "configure" ]]; then
    ./bootstrap.sh
    if [[ "$?" -ne 0 ]]; then
        echo "Failed to reconfigure IDN2"
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared \
    --disable-doc

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure IDN2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build IDN2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ "$IS_DARWIN" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! DYLD_LIBRARY_PATH="./.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test IDN2"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
elif [[ "$IS_LINUX" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! LD_LIBRARY_PATH="./.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test IDN2"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME2"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$IDN_TAR" "$IDN_DIR" "$IDN2_TAR" "$IDN2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-idn.sh 2>&1 | tee build-idn.log
    if [[ -e build-idn.log ]]; then
        rm -f build-idn.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
