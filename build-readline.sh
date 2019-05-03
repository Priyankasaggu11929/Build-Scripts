#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Readline from sources. Ncurses should
# be built first. If it is built, then tinfo will be used.

READLN_TAR=readline-7.0.tar.gz
READLN_DIR=readline-7.0
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
echo "********** Readline **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://ftp.gnu.org/gnu/readline/$READLN_TAR" -O "$READLN_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
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

# Fix broken Linux dynamic linker. tinfow or tinfo from ncurses
if [[ -n $(find /usr/local/lib64 -name '*tinfow*') ]]; then
    SH_TINFO="-ltinfow"
elif [[ -n $(find /usr/local/lib64 -name '*tinfo*') ]]; then
    SH_TINFO="-ltinfo"
fi

if [[ -n "$SH_TINFO" ]]; then
    for mfile in $(find "$PWD" -name 'Makefile'); do
        sed -e "s|SHLIB_LIBS =|SHLIB_LIBS = $SH_TINFO|g" "$mfile" > "$mfile.fixed"
        mv "$mfile.fixed" "$mfile"
    done
fi

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("check")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(grep -oIR 'runtime error:' ./* | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
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

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
