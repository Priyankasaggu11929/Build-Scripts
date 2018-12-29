#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and its dependencies from sources.

THIS_DIR=$(pwd)
function finish {
  cd "$THIS_DIR"
}
trap finish EXIT

PREFIX="$HOME/bootstrap"

# Copy cacerts to bootstrap
mkdir -p "$PREFIX/cacert/"
cp cacert.pem "$PREFIX/cacert/"

# Build OpenSSL
cd "$THIS_DIR"
cd openssl-1.0.2q

./config no-asm no-shared -fPIC \
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
cd wget-1.20.1

    CFLAGS="-I $PREFIX/include" \
    CXXFLAGS="-I $PREFIX/include" \
    LDFLAGS="-L $PREFIX/libs" \
    LDLIBS="-lssl -lcrypto -ldl" \
./configure \
    --prefix="$PREFIX" \
    --with-ssl=openssl \
    --without-zlib \
    --without-libpsl \
    --without-libuuid \
    --without-libidn

exit 0
