#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds P11-Kit from sources.

P11KIT_TAR=p11-kit-0.23.15.tar.gz
P11KIT_DIR=p11-kit-0.23.15
PKG_NAME=p11-kit

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

if ! ./build-libffi.sh
then
    echo "Failed to build libffi"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** p11-kit **********"
echo

if ! "$WGET" -O "$P11KIT_TAR" --ca-certificate="$DIGICERT_ROOT" \
     "https://github.com/p11-glue/p11-kit/releases/download/0.23.12/$P11KIT_TAR"
then
    echo "Failed to download p11-kit"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$P11KIT_DIR" &>/dev/null
gzip -d < "$P11KIT_TAR" | tar xf -
cd "$P11KIT_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

P11KIT_CONFIG_OPTS=("--enable-shared" "--prefix=$INSTX_PREFIX" "--libdir=$INSTX_LIBDIR")

# Use the path if available
if [[ -n "$SH_CACERT_PATH" ]]; then
    P11KIT_CONFIG_OPTS+=("--with-trust-paths=$SH_CACERT_PATH")
else
    P11KIT_CONFIG_OPTS+=("--without-trust-paths")
fi

if [[ "$IS_SOLARIS" -ne 0 ]]; then
    BUILD_CPPFLAGS+=("-D_XOPEN_SOURCE=500")
    BUILD_LDFLAGS=("-lsocket -lnsl ${BUILD_LDFLAGS[@]}")
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure "${P11KIT_CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure p11-kit"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# On Solaris the script puts /usr/gnu/bin on-path, so we get a useful grep
if [[ "$IS_SOLARIS" -ne 0 ]]; then
    for sfile in $(grep -IR '#define _XOPEN_SOURCE' "$PWD" | cut -f 1 -d ':' | sort | uniq); do
        sed -e '/#define _XOPEN_SOURCE/d' "$sfile" > "$sfile.fixed"
        mv "$sfile.fixed" "$sfile"
    done
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build p11-kit"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# https://bugs.freedesktop.org/show_bug.cgi?id=103402
# MAKE_FLAGS=("check" "V=1")
# if ! "$MAKE" "${MAKE_FLAGS[@]}"
# then
#     echo "Failed to test p11-kit"
#     [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
# fi

echo "Searching for errors hidden in log files"
COUNT=$(grep -oIR 'runtime error:' ./* | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test p11-kit"
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

    ARTIFACTS=("$P11KIT_TAR" "$P11KIT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-p11kit.sh 2>&1 | tee build-p11kit.log
    if [[ -e build-p11kit.log ]]; then
        rm -f build-p11kit.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
