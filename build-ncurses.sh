#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Ncurses from sources.

NCURSES_TAR=ncurses-6.1.tar.gz
NCURSES_DIR=ncurses-6.1
PKG_NAME=ncurses

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
echo "********** ncurses **********"
echo

if ! "$WGET" -O "$NCURSES_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/ncurses/$NCURSES_TAR"
then
    echo "Failed to download Ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$NCURSES_DIR" &>/dev/null
gzip -d < "$NCURSES_TAR" | tar xf -
cd "$NCURSES_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

CONFIG_OPTS=()
CONFIG_OPTS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTS+=("--disable-leaks")
CONFIG_OPTS+=("--with-shared")
CONFIG_OPTS+=("--with-cxx-shared")
CONFIG_OPTS+=("--without-ada")
CONFIG_OPTS+=("--enable-pc-files")
CONFIG_OPTS+=("--with-termlib")
CONFIG_OPTS+=("--disable-root-environ")
CONFIG_OPTS+=("--with-build-cc=$CC")
CONFIG_OPTS+=("--with-build-cxx=$CXX")
CONFIG_OPTS+=("--with-build-cpp=${BUILD_CPPFLAGS[*]}")
CONFIG_OPTS+=("--with-build-cflags=${BUILD_CFLAGS[*]}")
CONFIG_OPTS+=("--with-build-cxxflags=${BUILD_CXXFLAGS[*]}")
CONFIG_OPTS+=("--with-build-ldflags=${BUILD_LDFLAGS[*]}")
CONFIG_OPTS+=("--with-build-libs=${BUILD_LIBS[*]}")
CONFIG_OPTS+=("--with-pkg-config-libdir=${BUILD_PKGCONFIG[*]}")

# Ncurses can be built narrow or wide. There's no real way to
# know for sure, so we attempt to see what the distro is doing.
COUNT=$(find /usr/lib/ /usr/lib64/ -name 'ncurses*w.*' 2>/dev/null | wc -l)
if [[ "$COUNT" -ne 0 ]]; then
    echo "Enabling wide character version"
    echo ""
    CONFIG_OPTS+=("--enable-widec")
else
    echo "Enabling narrow character version"
    echo ""
fi

    # Ncurses use PKG_CONFIG_LIBDIR, not PKG_CONFIG_PATH???
    PKG_CONFIG_LIBDIR="${BUILD_PKGCONFIG[*]}" \
    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Fix Clang warning
if [[ "$IS_CLANG" -ne 0 ]]; then
    for mfile in $(find "$PWD" -name 'Makefile'); do
        sed -e 's|--param max-inline-insns-single=1200||g' "$mfile" > "$mfile.fixed"
        mv "$mfile.fixed" "$mfile"
    done
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("test")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | grep -v -E 'doc/|man/' | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test ncurses"
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

    ARTIFACTS=("$NCURSES_TAR" "$NCURSES_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-ncurses.sh 2>&1 | tee build-ncurses.log
    if [[ -e build-ncurses.log ]]; then
        rm -f build-ncurses.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
