#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and OpenSSL from sources. It
# is useful for bootstrapping a full Wget build.

# Binaries
WGET_TAR=wget-1.20.3.tar.gz
UNISTR_TAR=libunistring-0.9.10.tar.gz
SSL_TAR=openssl-1.0.2s.tar.gz

# Directories
BOOTSTRAP_DIR=$(pwd)
WGET_DIR=wget-1.20.3
UNISTR_DIR=libunistring-0.9.10
SSL_DIR=openssl-1.0.2s

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
IS_SOLARIS=$(echo -n $(uname -s 2>&1) | grep -i -c 'sunos')
IS_FREEBSD=$(echo -n $(uname -s 2>&1) | grep -i -c 'freebsd')
IS_OLD_DARWIN=$(system_profiler SPSoftwareDataType 2>/dev/null | grep -i -c -E "OS X 10\.[0-5]")

if [[ "$IS_DARWIN" -ne "0" ]]; then
    DARWIN_CFLAGS="-force_cpusubtype_ALL"
fi

if [[ "$IS_OLD_DARWIN" -ne "0" ]]; then
    MAKEDEPPROG="gcc -M"
elif [[ "$IS_SOLARIS" -ne "0" ]]; then
    MAKEDEPPROG="gcc -M"
else
    MAKEDEPPROG="$CC"
fi

# Welcome to the Jungle...
cd "$BOOTSTRAP_DIR"

############################## CA Certs ##############################

# Copy our copy of cacerts to bootstrap
mkdir -p "$PREFIX/cacert/"
cp cacert.pem "$PREFIX/cacert/cacert.pem"

############################## OpenSSL ##############################

echo
echo "*************************************************"
echo "Building OpenSSL"
echo "*************************************************"
echo

rm -rf "$SSL_DIR" &>/dev/null
gzip -d < "$SSL_TAR" | tar xf -
cd "$BOOTSTRAP_DIR/$SSL_DIR"

    KERNEL_BITS="$INSTX_BITNESS" \
./config \
    --prefix="$PREFIX" \
    no-asm no-shared no-dso no-engine -fPIC

if [[ "$IS_FREEBSD" -ne 0 ]]
then
    for file in $(find "$PWD" -name 'Makefile')
    do
        sed -e 's|-lssl|-l:libssl.a|g' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"
        sed -e 's|-lcrypto|-l:libcrypto.a|g' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"
    done
fi

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

############################## Unistring ##############################

cd "$BOOTSTRAP_DIR"

echo
echo "*************************************************"
echo "Building Unistring"
echo "*************************************************"
echo

rm -rf "$UNISTR_DIR" &>/dev/null
gzip -d < "$UNISTR_TAR" | tar xf -
cd "$BOOTSTRAP_DIR/$UNISTR_DIR"

    CFLAGS="$CFLAGS $DARWIN_CFLAGS" \
    LDFLAGS="$LDFLAGS $STATIC_LDFLAGS" \
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig/" \
    OPENSSL_LIBS="$PREFIX/lib/libssl.a $PREFIX/lib/libcrypto.a" \
./configure \
    --prefix="$PREFIX" \
    --disable-shared

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Unistring"
    exit 1
fi

if ! make -j "$INSTX_JOBS" V=1; then
    echo "Failed to build Unistring"
    exit 1
fi

if ! make install; then
    echo "Failed to install Unistring"
    exit 1
fi

############################## Wget ##############################

cd "$BOOTSTRAP_DIR"

echo
echo "*************************************************"
echo "Building Wget"
echo "*************************************************"
echo

rm -rf "$WGET_DIR" &>/dev/null
gzip -d < "$WGET_TAR" | tar xf -
cd "$BOOTSTRAP_DIR/$WGET_DIR"

# Install recipe does not overwrite a config, if present.
if [[ -f "$PREFIX/etc/wgetrc" ]]; then
    rm "$PREFIX/etc/wgetrc"
fi

    CFLAGS="$CFLAGS $DARWIN_CFLAGS" \
    LDFLAGS="$LDFLAGS $STATIC_LDFLAGS" \
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
    --disable-iri

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Wget"
    exit 1
fi

if ! make -j "$INSTX_JOBS" V=1; then
    echo "Failed to build Wget"
    exit 1
fi

if ! make install; then
    echo "Failed to install Wget"
    exit 1
fi

mkdir -p "$PREFIX/cacert/"
cp ../cacert.pem "$PREFIX/cacert/cacert.pem"

echo "" >> "$PREFIX/etc/wgetrc"
echo "# cacert.pem location" >> "$PREFIX/etc/wgetrc"
echo "ca_directory = $PREFIX/cacert/" >> "$PREFIX/etc/wgetrc"
echo "ca_certificate = $PREFIX/cacert/cacert.pem" >> "$PREFIX/etc/wgetrc"
echo "" >> "$PREFIX/etc/wgetrc"

# Cleanup
if true; then
    cd "$CURR_DIR"
    rm -rf "$WGET_DIR" &>/dev/null
    rm -rf "$UNISTR_DIR" &>/dev/null
    rm -rf "$SSL_DIR" &>/dev/null
fi

exit 0
