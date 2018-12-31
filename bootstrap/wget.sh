#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and OpenSSL from sources. It
# is useful for bootstrapping a full Wget build.

# Binaries
WGET_TAR=wget-1.20.1.tar.gz
SSL_TAR=openssl-1.0.2q.tar.gz

# Directories
BOOTSTRAP_DIR=$(pwd)
WGET_DIR=wget-1.20.1
SSL_DIR=openssl-1.0.2q

# Install location
PREFIX="$HOME/bootstrap"

###############################################################################

CURR_DIR=$(pwd)
function finish {
  cd "$CURR_DIR"
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=2}"

############################## Misc ##############################

: "${CC:=cc}"
INSTX_BITNESS=64
if ! $CC $CFLAGS bitness.c -o /dev/null &>/dev/null; then
    INSTX_BITNESS=32
fi

IS_DARWIN=$(echo -n $(uname -s 2>&1) | grep -i -c 'darwin')
if [[ "$IS_DARWIN" -ne "0" ]]; then
    DARWIN_CFLAGS="-force_cpusubtype_ALL"
fi

IS_OLD_DARWIN=$(system_profiler SPSoftwareDataType 2>/dev/null | grep -i -c "OS X 10.5")
if [[ "$IS_OLD_DARWIN" -ne "0" ]]; then
    MAKEDEPPROG="gcc -M"
else
    MAKEDEPPROG="$CC"
fi

############################## CA Certs ##############################

# Copy our copy of cacerts to bootstrap
mkdir -p "$PREFIX/cacert/"
cp cacert.pem "$PREFIX/cacert/"

############################## OpenSSL ##############################

# Build OpenSSL
cd "$BOOTSTRAP_DIR"

rm -rf "$SSL_DIR" &>/dev/null
gzip -d < "$SSL_TAR" | tar xf -
cd "$BOOTSTRAP_DIR/$SSL_DIR"

    KERNEL_BITS="$INSTX_BITNESS" \
./config \
    --prefix="$PREFIX" \
    no-asm no-shared no-dso no-engine -fPIC

if ! make MAKEDEPPROG="$MAKEDEPPROG" depend; then
    echo "Failed to update OpenSSL"
    exit 1
fi

if ! make -j "$INSTX_JOBS"; then
    echo "Failed to build OpenSSL"
    exit 1
fi

if ! make install_sw; then
    echo "Failed to install OpenSSL"
    exit 1
fi

############################## Wget ##############################

# Build Wget
cd "$BOOTSTRAP_DIR"

rm -rf "$WGET_DIR" &>/dev/null
gzip -d < "$WGET_TAR" | tar xf -

# Install recipe does not overwrite a config, if present.
if [[ -f "$PREFIX/etc/wgetrc" ]]; then
    rm "$PREFIX/etc/wgetrc"
fi

cp wget.patch "$WGET_DIR"
cd "$WGET_DIR"

if ! patch -u -p0 < wget.patch; then
    echo "Wget patch failed"
    exit 1
fi

    CFLAGS="$CFLAGS $DARWIN_CFLAGS" \
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig/" \
    OPENSSL_LIBS="$PREFIX/lib/libssl.a $PREFIX/lib/libcrypto.a" \
./configure \
    --sysconfdir="$PREFIX/etc" \
    --prefix="$PREFIX" \
    --with-ssl=openssl \
    --without-zlib \
    --without-libpsl \
    --without-libuuid \
    --without-libidn \
    --without-cares \
    --disable-pcre \
    --disable-pcre2 \
    --disable-nls \
    --disable-iri \
    --without-libiconv-prefix \
    --without-libunistring-prefix

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Wget"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if ! make -j "$INSTX_JOBS"; then
    echo "Failed to build Wget"
    exit 1
fi

if ! make install; then
    echo "Failed to install Wget"
    exit 1
fi

echo "" >> "$PREFIX/etc/wgetrc"
echo "# cacert.pem location" >> "$PREFIX/etc/wgetrc"
echo "ca_directory = $PREFIX/cacert/" >> "$PREFIX/etc/wgetrc"
echo "ca_certificate = $PREFIX/cacert/cacert.pem" >> "$PREFIX/etc/wgetrc"
echo "" >> "$PREFIX/etc/wgetrc"

# Cleanup
if true; then
    cd "$CURR_DIR"
    rm -rf "$WGET_DIR" &>/dev/null
    rm -rf "$SSL_DIR" &>/dev/null
fi

exit 0
