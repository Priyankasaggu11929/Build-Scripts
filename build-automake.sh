#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Automake from sources. A separate
# script is available for Autotools for brave souls.

AUTOMAKE_TAR=automake-1.15.1.tar.gz
AUTOMAKE_DIR=automake-1.15.1

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

DIGICERT_ROOT="$DIGICERT_ROOT"
if [[ ! -f "$HOME/.cacert/lets-encrypt-root-x3.pem" ]]; then
    echo "Automake requires several CA roots. Please run build-cacerts.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

echo
echo "********** Automake **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://ftp.gnu.org/gnu/automake/$AUTOMAKE_TAR" -O "$AUTOMAKE_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download Automake"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$AUTOMAKE_DIR" &>/dev/null
gzip -d < "$AUTOMAKE_TAR" | tar xf -
cd "$AUTOMAKE_DIR"

# Avoid reconfiguring.
if [[ ! -e "configure" ]]; then
    autoreconf --force --install
    if [[ "$?" -ne 0 ]]; then
        echo "Failed to reconfigure Automake"
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
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR"

sed -e 's|^MAKEINFO =.*|MAKEINFO = true|g' Makefile > Makefile.fixed
mv Makefile.fixed Makefile

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Automake"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Automake"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Update program cache
[[ "$0" = "${BASH_SOURCE[0]}" ]] && hash -r

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$AUTOMAKE_TAR" "$AUTOMAKE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-automake.sh 2>&1 | tee build-automake.log
    if [[ -e build-automake.log ]]; then
        rm -f build-automake.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
