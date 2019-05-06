
#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds cURL from sources.

CURL_TAR=curl-7.64.1.tar.gz
CURL_DIR=curl-7.64.1
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

if ! ./build-iconv.sh
then
    echo "Failed to build iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-idn.sh
then
    echo "Failed to build IDN"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-pcre.sh
then
    echo "Failed to build PCRE and PCRE2"
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

CONFIG_OPTIONS=()
CONFIG_OPTIONS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTIONS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTIONS+=("--enable-shared")
CONFIG_OPTIONS+=("--enable-static")
CONFIG_OPTIONS+=("--enable-optimize")
CONFIG_OPTIONS+=("--enable-symbol-hiding")
CONFIG_OPTIONS+=("--enable-http")
CONFIG_OPTIONS+=("--enable-ftp")
CONFIG_OPTIONS+=("--enable-file")
CONFIG_OPTIONS+=("--enable-ldap")
CONFIG_OPTIONS+=("--enable-ldaps")
CONFIG_OPTIONS+=("--enable-rtsp")
CONFIG_OPTIONS+=("--enable-proxy")
CONFIG_OPTIONS+=("--enable-dict")
CONFIG_OPTIONS+=("--enable-telnet")
CONFIG_OPTIONS+=("--enable-tftp")
CONFIG_OPTIONS+=("--enable-pop3")
CONFIG_OPTIONS+=("--enable-imap")
CONFIG_OPTIONS+=("--enable-smb")
CONFIG_OPTIONS+=("--enable-smtp")
CONFIG_OPTIONS+=("--enable-gopher")
CONFIG_OPTIONS+=("--enable-cookies")
CONFIG_OPTIONS+=("--enable-ipv6")
CONFIG_OPTIONS+=("--with-nghttp2")
CONFIG_OPTIONS+=("--with-zlib=$INSTX_PREFIX")
CONFIG_OPTIONS+=("--with-ssl=$INSTX_PREFIX")
CONFIG_OPTIONS+=("--with-libidn2=$INSTX_PREFIX")
CONFIG_OPTIONS+=("--without-gnutls")
CONFIG_OPTIONS+=("--without-polarssl")
CONFIG_OPTIONS+=("--without-mbedtls")
CONFIG_OPTIONS+=("--without-cyassl")
CONFIG_OPTIONS+=("--without-nss")
CONFIG_OPTIONS+=("--without-libssh2")
CONFIG_OPTIONS+=("--with-ca-bundle=$SH_CACERT_FILE")

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="-lidn2 -lssl -lcrypto -lz ${BUILD_LIBS[*]}" \
./configure "${CONFIG_OPTIONS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

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
COUNT=$(grep -oIR 'runtime error:' ./* | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test cURL"
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
