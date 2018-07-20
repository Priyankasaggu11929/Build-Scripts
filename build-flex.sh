#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Flex from sources.

FLEX_TAR=v2.6.4.tar.gz
FLEX_DIR=flex-2.6.4

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=4}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./build-environ.sh
then
    echo "Failed to set environment"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

DIGICERT_ROOT="$HOME/.cacert/digicert-root-ca.pem"
if [[ ! -f "$DIGICERT_ROOT" ]]; then
    echo "Libtool requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

if ! ./build-gettext.sh
then
    echo "Failed to build iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** Flex **********"
echo

"$WGET" --ca-certificate="$DIGICERT_ROOT" "https://github.com/westes/flex/archive/$FLEX_TAR" -O "$FLEX_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Flex"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$FLEX_DIR" &>/dev/null
gzip -d < "$FLEX_TAR" | tar xf -
cd "$FLEX_DIR"

# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec; thanks NM.
# AIX needs the execute bit reset on the file.
sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' configure.ac > configure.ac.fixed
mv configure.ac.fixed configure.ac; chmod +x configure.ac

sed -e 's|1\.11\.3|1\.11\.2|g' configure.ac > configure.ac.fixed
mv configure.ac.fixed configure.ac; chmod +x configure.ac
sed -e 's|dist-lzip | |g' configure.ac > configure.ac.fixed
mv configure.ac.fixed configure.ac; chmod +x configure.ac

./autogen.sh

if [[ "$?" -ne "0" ]]; then
    echo "Failed to autogen Flex"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Flex"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Flex"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("check")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Flex"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$FLEX_TAR" "$FLEX_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-flex.sh 2>&1 | tee build-flex.log
    if [[ -e build-flex.log ]]; then
        rm -f build-flex.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
