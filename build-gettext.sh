#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GetText from sources.

# iConvert and GetText are unique among packages. They have circular
# dependencies on one another. We have to build iConv, then GetText,
# and iConv again. Also see https://www.gnu.org/software/libiconv/.
# The script that builds iConvert and GetText in accordance to specs
# is build-iconv-gettext.sh. You should use build-iconv-gettext.sh
# instead of build-gettext.sh directly

GETTEXT_TAR=gettext-0.20.1.tar.gz
GETTEXT_DIR=gettext-0.20.1
PKG_NAME=gettext

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
echo "********** GetText **********"
echo

if ! "$WGET" -O "$GETTEXT_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/gettext/$GETTEXT_TAR"
then
    echo "Failed to download GetText"
    exit 1
fi

rm -rf "$GETTEXT_DIR" &>/dev/null
gzip -d < "$GETTEXT_TAR" | tar xf -
cd "$GETTEXT_DIR"

cp ../patch/gettext.patch .
patch -u -p0 < gettext.patch
echo ""

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared --with-pic

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure GetText"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GetText"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test GetText"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test GetText"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
    echo "$SUDO_PASSWORD" | sudo -S rm -rf "$INSTX_PREFIX/share/doc/gettext"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
    rm -rf "$INSTX_PREFIX/share/doc/gettext"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$GETTEXT_TAR" "$GETTEXT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-gettext.sh 2>&1 | tee build-gettext.log
    if [[ -e build-gettext.log ]]; then
        rm -f build-gettext.log
    fi
fi

exit 0
