#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and its dependencies from sources.

THIS_DIR=$(pwd)
function finish {
  cd "$THIS_DIR"
}
trap finish EXIT

# Binaries
WGET_TAR=wget-1.20.1.tar.gz
SSL_TAR=openssl-1.0.2q.tar.gz

# Directories
WGET_DIR=wget-1.20.1
SSL_DIR=openssl-1.0.2q

# Install location
PREFIX="$HOME/bootstrap"

# Copy cacerts to bootstrap
mkdir -p "$PREFIX/cacert/"
cp cacert.pem "$PREFIX/cacert/"

# Build OpenSSL
cd "$THIS_DIR"

rm -rf "$SSL_DIR" &>/dev/null
gzip -d < "$SSL_TAR" | tar xf -
cd "$SSL_DIR"

./config no-asm no-shared no-dso no-engine -fPIC \
    --prefix="$PREFIX"

if ! make depend; then
    echo "OpenSSL update failed"
	exit 1
fi

if ! make -j 2; then
    echo "OpenSSL build failed"
	exit 1
fi

if ! make install_sw; then
    echo "OpenSSL install failed"
	exit 1
fi

# Build Wget
cd "$THIS_DIR"

rm -rf "$WGET_DIR" &>/dev/null
gzip -d < "$WGET_TAR" | tar xf -

if [[ -f "$PREFIX/etc/wgetrc" ]]; then
    rm "$PREFIX/etc/wgetrc"
fi

cp wget.patch "$WGET_DIR/src"
cd "$WGET_DIR/src"
patch < wget.patch

cd ".."

    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig/" \
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

if ! make -j 2; then
    echo "Wget build failed"
	exit 1
fi

if ! make install; then
    echo "Wget install failed"
	exit 1
fi

echo "" >> "$PREFIX/etc/wgetrc"
echo "# cacert.pem location" >> "$PREFIX/etc/wgetrc"
echo "ca_directory = $PREFIX/cacert/" >> "$PREFIX/etc/wgetrc"
echo "ca_certificate = $PREFIX/cacert/cacert.pem" >> "$PREFIX/etc/wgetrc"
echo "" >> "$PREFIX/etc/wgetrc"

# Cleanup
rm -rf "$WGET_DIR" &>/dev/null
rm -rf "$SSL_DIR" &>/dev/null

exit 0
