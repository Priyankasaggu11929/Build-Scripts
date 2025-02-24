#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Autotools from sources. A separate
# script is available for Libtool for brave souls.

# Trying to update Autotools may be more trouble than it is
# worth. If the upgrade goes bad, then you can uninstall
# it with the script clean-autotools.sh

M4_TAR=m4-1.4.18.tar.gz
M4_DIR=m4-1.4.18

AUTOCONF_TAR=autoconf-2.69.tar.gz
AUTOCONF_DIR=autoconf-2.69

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
    exit 1
fi

# The password should die when this subshell goes out of scope
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

echo
echo "********** M4 **********"
echo

if ! "$WGET" -O "$M4_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/m4/$M4_TAR"
then
    echo "Failed to download M4"
    exit 1
fi

rm -rf "$M4_DIR" &>/dev/null
gzip -d < "$M4_TAR" | tar xf -
cd "$M4_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure M4"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "MAKEINFO=true")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build M4"
    exit 1
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

# Update program cache
hash -r &>/dev/null

###############################################################################

echo
echo "********** Autoconf **********"
echo

if ! "$WGET" -O "$AUTOCONF_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/autoconf/$AUTOCONF_TAR"
then
    echo "Failed to download libtool"
    exit 1
fi

rm -rf "$AUTOCONF_DIR" &>/dev/null
gzip -d < "$AUTOCONF_TAR" | tar xf -
cd "$AUTOCONF_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Autoconf"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Autoconf"
    exit 1
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

# Update program cache
hash -r &>/dev/null

###############################################################################

echo
echo "********** Automake **********"
echo

if ! "$WGET" -O "$AUTOMAKE_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/automake/$AUTOMAKE_TAR"
then
    echo "Failed to download Automake"
    exit 1
fi

rm -rf "$AUTOMAKE_DIR" &>/dev/null
gzip -d < "$AUTOMAKE_TAR" | tar xf -
cd "$AUTOMAKE_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR"

sed -e 's|^MAKEINFO =.*|MAKEINFO = true|g' Makefile > Makefile.fixed
mv Makefile.fixed Makefile

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Automake"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Automake"
    exit 1
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

# Update program cache
hash -r &>/dev/null

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$M4_TAR" "$M4_DIR" "$AUTOCONF_TAR" "$AUTOCONF_DIR"
        "$AUTOCONF_ARCH_TAR" "$AUTOCONF_ARCH_DIR" "$AUTOMAKE_TAR" "$AUTOMAKE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-autotools.sh 2>&1 | tee build-autotools.log
    if [[ -e build-autotools.log ]]; then
        rm -f build-autotools.log
    fi
fi

exit 0
