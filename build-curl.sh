
#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds cURL from sources.

CURL_TAR=curl-7.65.1.tar.gz
CURL_DIR=curl-7.65.1
PKG_NAME=curl

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
    echo "Failed to install CA certs"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-idn2.sh
then
    echo "Failed to build IDN2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-pcre2.sh
then
    echo "Failed to build PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-openldap.sh
then
    echo "Failed to build OpenLDAP"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** cURL **********"
echo

if ! "$WGET" -O "$CURL_TAR" --ca-certificate="$CA_ZOO" \
     "https://curl.haxx.se/download/$CURL_TAR"
then
    echo "Failed to download cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$CURL_DIR" &>/dev/null
gzip -d < "$CURL_TAR" | tar xf -
cd "$CURL_DIR"

cp ../patch/curl.patch .
patch -u -p0 < curl.patch
echo ""

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

CONFIG_OPTS=()
CONFIG_OPTS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--enable-static")
CONFIG_OPTS+=("--enable-optimize")
CONFIG_OPTS+=("--enable-symbol-hiding")
CONFIG_OPTS+=("--enable-http")
CONFIG_OPTS+=("--enable-ftp")
CONFIG_OPTS+=("--enable-file")
CONFIG_OPTS+=("--enable-ldap")
CONFIG_OPTS+=("--enable-ldaps")
CONFIG_OPTS+=("--enable-rtsp")
CONFIG_OPTS+=("--enable-proxy")
CONFIG_OPTS+=("--enable-dict")
CONFIG_OPTS+=("--enable-telnet")
CONFIG_OPTS+=("--enable-tftp")
CONFIG_OPTS+=("--enable-pop3")
CONFIG_OPTS+=("--enable-imap")
CONFIG_OPTS+=("--enable-smb")
CONFIG_OPTS+=("--enable-smtp")
CONFIG_OPTS+=("--enable-gopher")
CONFIG_OPTS+=("--enable-cookies")
CONFIG_OPTS+=("--enable-ipv6")
CONFIG_OPTS+=("--with-nghttp2")
CONFIG_OPTS+=("--with-zlib=$INSTX_PREFIX")
CONFIG_OPTS+=("--with-ssl=$INSTX_PREFIX")
CONFIG_OPTS+=("--with-libidn2=$INSTX_PREFIX")
CONFIG_OPTS+=("--without-gnutls")
CONFIG_OPTS+=("--without-polarssl")
CONFIG_OPTS+=("--without-mbedtls")
CONFIG_OPTS+=("--without-cyassl")
CONFIG_OPTS+=("--without-nss")
CONFIG_OPTS+=("--without-libssh2")
CONFIG_OPTS+=("--with-ca-bundle=$SH_CACERT_FILE")

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="-lidn2 -lssl -lcrypto -lz ${BUILD_LIBS[*]}" \
./configure "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

# Disable Valgrind with "TFLAGS=-n". Too many findings due
# to -march=native. We also want the sanitizers since others
# are doing the Valgrind testing.
MAKE_FLAGS=("test" "TFLAGS=-n" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
#    echo "Failed to test cURL"
#    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    :
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
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

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$CURL_TAR" "$CURL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-curl.sh 2>&1 | tee build-curl.log
    if [[ -e build-curl.log ]]; then
        rm -f build-curl.log
    fi

    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
