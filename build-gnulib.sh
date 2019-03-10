#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Gnulib from sources.

# Gnulib is distributed as source from GitHub. No packages
# are available for download. Also see
# https://www.linux.com/news/using-gnulib-improve-software-portability

GNULIB_DIR=gnulib
PKG_NAME=Gnulib

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

echo
echo "********** Gnulib **********"
echo

if ! git clone --depth=3 git://git.savannah.gnu.org/gnulib.git "$GNULIB_DIR"
then
    echo "Failed to clone Gnulib"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

cd "$GNULIB_DIR"

#cp ../patch/gnulib.patch .
#patch -u -p0 < gnulib.patch
#echo ""

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
    SHELL="$(command -v bash)" \
"$MAKE" "-j" "$INSTX_JOBS" "V=1"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to build Gnulib"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ "$IS_DARWIN" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! DYLD_LIBRARY_PATH="lib/.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test Gnulib"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
elif [[ "$IS_LINUX" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! LD_LIBRARY_PATH="lib/.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test Gnulib"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
else
	MAKE_FLAGS=("check" "V=1")
	if ! "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test Gnulib"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
fi

echo "Searching for errors hidden in log files"
COUNT=$(grep -oIR 'runtime error' | grep -v 'ChangeLog' | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Gnulib"
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

    ARTIFACTS=("$GNULIB_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-Gnulib.sh 2>&1 | tee build-gnulib.log
    if [[ -e build-gnulib.log ]]; then
        rm -f build-gnulib.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
