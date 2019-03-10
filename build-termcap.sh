#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Termcap from sources.

TERMCAP_TAR=termcap-1.3.1.tar.gz
TERMCAP_DIR=termcap-1.3.1
PKG_NAME=termcap

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
    source ./build-password.sh
fi

###############################################################################

echo
echo "********** Termcap **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://ftp.gnu.org/gnu/termcap/$TERMCAP_TAR" -O "$TERMCAP_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download Termcap"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$TERMCAP_DIR" &>/dev/null
gzip -d < "$TERMCAP_TAR" | tar xf -
cd "$TERMCAP_DIR"

sed -e "s|^CPPFLAGS = *|CPPFLAGS = @CPPFLAGS@ |g" Makefile.in > Makefile.in.fixed
mv Makefile.in.fixed Makefile.in
sed -e "s|^CFLAGS = *|CFLAGS = @CFLAGS@ |g" Makefile.in > Makefile.in.fixed
mv Makefile.in.fixed Makefile.in
sed -e "s|^CXXFLAGS = *|CXXFLAGS = @CXXFLAGS@ |g" Makefile.in > Makefile.in.fixed
mv Makefile.in.fixed Makefile.in
sed -e 's|$(CC) -c $(CPPFLAGS)|$(CC) -c $(CPPFLAGS) $(CFLAGS) |g' Makefile.in > Makefile.in.fixed
mv Makefile.in.fixed Makefile.in
sed -e 's|oldincludedir|includedir|g' Makefile.in > Makefile.in.fixed
mv Makefile.in.fixed Makefile.in
touch -t 197001010000 Makefile.in

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    # Termcap does not honor anything below. Its why we have so many sed's.
    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" \
    --enable-shared \
    --enable-install-termcap --with-termcap="$INSTX_PREFIX/etc"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Termcap"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

sed -e '42i#include <unistd.h>' tparam.c > tparam.c.fixed
mv tparam.c.fixed tparam.c
sed -e "/^oldincludedir/d" Makefile > Makefile.fixed
mv Makefile.fixed Makefile
sed -e "s|prefix =.*|prefix = $INSTX_PREFIX|g" Makefile > Makefile.fixed
mv Makefile.fixed Makefile
sed -e "s|exec_prefix = .*|exec_prefix = $INSTX_PREFIX|g" Makefile > Makefile.fixed
mv Makefile.fixed Makefile
sed -e "s|libdir =.*|libdir = $INSTX_LIBDIR|g" Makefile > Makefile.fixed
mv Makefile.fixed Makefile
sed -e "s|includedir = .*|includedir = $INSTX_PREFIX/include|g" Makefile > Makefile.fixed
mv Makefile.fixed Makefile

ARFLAGS="cr"
MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! ARFLAGS="$ARFLAGS" "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Termcap"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# libdir="$INSTX_LIBDIR"
MAKE_FLAGS=("install" "libdir=$INSTX_LIBDIR")
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

    ARTIFACTS=("$TERMCAP_TAR" "$TERMCAP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-termcap.sh 2>&1 | tee build-termcap.log
    if [[ -e build-termcap.log ]]; then
        rm -f build-termcap.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
