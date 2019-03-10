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
    source ./build-password.sh
fi

###############################################################################

echo
echo "********** ncurses **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://ftp.gnu.org/pub/gnu/ncurses/$NCURSES_TAR" -O "$NCURSES_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download Ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$NCURSES_DIR" &>/dev/null
gzip -d < "$NCURSES_TAR" | tar xf -
cd "$NCURSES_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

# Ncurses fails to configure if an old version is present.
# Configure will attempt to use old headers, which are missing symbols.
# This seems to be the only reliable way to delete the old version
# since we can't 'configure' and then 'make uninstall'.
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S find "$INSTX_PREFIX" -name '*curse*' -exec rm -rf {} 2>/dev/null \;
else
    find "$INSTX_PREFIX" -name '*curse*' -exec rm -rf {} \;
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --with-shared --with-cxx-shared --without-ada --enable-pc-files \
    --with-termlib --enable-widec --disable-root-environ \
    --with-build-cc="$CC" --with-build-cxx="$CXX" \
    --with-build-cpp="${BUILD_CPPFLAGS[*]}" \
    --with-build-cflags="${BUILD_CPPFLAGS[*]} ${BUILD_CFLAGS[*]}" \
    --with-build-cxxflags="${BUILD_CPPFLAGS[*]} ${BUILD_CXXFLAGS[*]}" \
    --with-build-ldflags="${BUILD_LDFLAGS[*]}" \
    --with-build-libs="${BUILD_LIBS[*]}"

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

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Uninstall the existing copy first. Ncurses does not install over top of itself
MAKE_FLAGS=("uninstall")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
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
