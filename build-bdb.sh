
#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds BerkleyDB from sources.

BDB_TAR=db-6.2.32.tar.gz
BDB_DIR=db-6.2.32
PKG_NAME=bdb

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
if ! source ./build-environ.sh
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
    source ./build-password.sh
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** Berkely DB **********"
echo

cp "bootstrap/$BDB_TAR" .
rm -rf "$BDB_DIR" &>/dev/null
gzip -d < "$BDB_TAR" | tar xf -

cd "$BDB_DIR"

cp ../patch/db.patch .
patch -u -p0 < db.patch
echo ""

cd "$CURR_DIR"
cd "$BDB_DIR/dist"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../../fix-config.sh

cd "$CURR_DIR"
cd "$BDB_DIR/build_unix"

CONFIG_OPTIONS=()
CONFIG_OPTIONS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTIONS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTIONS+=("--with-tls=openssl")

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
../dist/configure "${CONFIG_OPTIONS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure BerkleyDB"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build BerkleyDB"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# No check or test recipes
#MAKE_FLAGS=("check" "V=1")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test BerkleyDB"
#    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
#fi

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

    ARTIFACTS=("$BDB_TAR" "$BDB_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openldap.sh 2>&1 | tee build-openldap.log
    if [[ -e build-openldap.log ]]; then
        rm -f build-openldap.log
    fi

    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
