#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Readline from sources. Ncurses should
# be built first. If it is built, then tinfo will be used.

READLN_TAR=readline-8.0.tar.gz
READLN_DIR=readline-8.0
PKG_NAME=readline

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

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
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

if ! ./build-ncurses.sh
then
    echo "Failed to build ncurses"
    exit 1
fi

###############################################################################

echo
echo "********** Readline **********"
echo

if ! "$WGET" -O "$READLN_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/readline/$READLN_TAR"
then
    echo "Failed to download Readline"
    exit 1
fi

rm -rf "$READLN_DIR" &>/dev/null
gzip -d < "$READLN_TAR" | tar xf -
cd "$READLN_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

if [[ "$IS_DARWIN" -ne 0 ]]; then
    BUILD_CPPFLAGS+=("-DNEED_EXTERN_PC")
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Readline"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Readline"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Readline"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Readline"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S rm -f "$INSTX_LIBDIR/libreadline*.*"
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    rm -rf "$INSTX_LIBDIR/libreadline*.*"
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$READLN_TAR" "$READLN_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-readline.sh 2>&1 | tee build-readline.log
    if [[ -e build-readline.log ]]; then
        rm -f build-readline.log
    fi
fi

exit 0
