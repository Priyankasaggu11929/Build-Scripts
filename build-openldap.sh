
#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds OpenLDAP from sources.

LDAP_TAR=openldap-2.4.47.tgz
LDAP_DIR=openldap-2.4.47
PKG_NAME=openldap

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

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-bdb.sh
then
    echo "Failed to build Berkely DB"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** OpenLDAP **********"
echo

"$WGET" --ca-certificate="$GO_DADDY_ROOT" "https://gpl.savoirfairelinux.net/pub/mirrors/openldap/openldap-release/$LDAP_TAR" -O "$LDAP_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download OpenLDAP"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$LDAP_DIR" &>/dev/null
gzip -d < "$LDAP_TAR" | tar xf -
cd "$LDAP_DIR"

cp ../patch/openldap.patch .
patch -u -p0 < openldap.patch
echo ""

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

sed 's|0x060014|0x060300|g' configure > configure.new
mv configure.new configure
chmod +x configure

"$WGET" --ca-certificate="$CACERT_ZOO" 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD' -O build/config.guess

"$WGET" --ca-certificate="$CACERT_ZOO" 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD' -O build/config.sub

CONFIG_OPTIONS=()
CONFIG_OPTIONS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTIONS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTIONS+=("--with-tls=openssl")

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
./configure "${CONFIG_OPTIONS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure OpenLDAP"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenLDAP"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Can't pass self tests on ARM
#MAKE_FLAGS=("check" "V=1")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test OpenLDAP"
#    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
#fi

# Too many findings...
# https://www.openldap.org/its/index.cgi/Incoming?id=8988
# https://www.openldap.org/its/index.cgi/Incoming?id=8989
#echo "Searching for errors hidden in log files"
#COUNT=$(grep -oIR 'runtime error' | wc -l)
#if [[ "${COUNT}" -ne 0 ]];
#then
#    echo "Failed to test OpenLDAP"
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

    ARTIFACTS=("$LDAP_TAR" "$LDAP_DIR")
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
