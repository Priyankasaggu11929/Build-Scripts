#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GnuTLS and its dependencies from sources.

GNUTLS_XZ=gnutls-3.6.8.tar.xz
GNUTLS_TAR=gnutls-3.6.8.tar
GNUTLS_DIR=gnutls-3.6.8
PKG_NAME=gnutls

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
    echo "Failed to install CA certs"
    exit 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

if ! ./build-tasn1.sh
then
    echo "Failed to build Tasn1"
    exit 1
fi

###############################################################################

if ! ./build-ncurses.sh
then
    echo "Failed to build ncurses"
    exit 1
fi

###############################################################################

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

if ! ./build-idn2.sh
then
    echo "Failed to build IDN2"
    exit 1
fi

###############################################################################

if ! ./build-expat.sh
then
    echo "Failed to build Expat"
    exit 1
fi

###############################################################################

if ! ./build-nettle.sh
then
    echo "Failed to build Nettle"
    exit 1
fi

###############################################################################

if ! ./build-unbound.sh
then
    echo "Failed to build Unbound"
    exit 1
fi

###############################################################################

if ! ./build-p11kit.sh
then
    echo "Failed to build P11-Kit"
    exit 1
fi

###############################################################################

echo
echo "********** GnuTLS **********"
echo

if ! "$WGET" -O "$GNUTLS_XZ" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.6/$GNUTLS_XZ"
then
    echo "Failed to download GnuTLS"
    exit 1
fi

rm -rf "$GNUTLS_TAR" "$GNUTLS_DIR" &>/dev/null
unxz "$GNUTLS_XZ" && tar -xf "$GNUTLS_TAR"
cd "$GNUTLS_DIR"

#cp ../patch/gnutls.patch .
#patch -u -p0 < gnutls.patch
#echo ""

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

# Solaris is a tab bit stricter than libc
if [[ "$IS_SOLARIS" -ne 0 ]]; then
    # Don't use CPPFLAGS. _XOPEN_SOURCE will cross-pollinate into CXXFLAGS.
    BUILD_CFLAGS+=("-D_XOPEN_SOURCE=600 -std=gnu99")
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --enable-shared \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --enable-seccomp-tests \
    --disable-guile \
    --disable-ssl2-support \
    --disable-ssl3-support \
    --disable-gtk-doc \
    --disable-gtk-doc-html \
    --disable-gtk-doc-pdf \
    --with-p11-kit \
    --with-libregex \
    --with-nettle-prefix="$INSTX_PREFIX" \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libintl-prefix="$INSTX_PREFIX" \
    --with-libseccomp-prefix="$INSTX_PREFIX" \
    --with-unbound-root-key-file="$SH_UNBOUND_ROOTKEY_FILE"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure GnuTLS"
    exit 1
fi

for file in $(find "$PWD/tests" -iname 'Makefile')
do
    # Test suite does not compile with NDEBUG defined. Configure
    # does not provide option for separate CFLAGS or CXXFLAGS.
    # Makefile does not honor CFLAGS or CXXFLAGS on command line.
    echo "Patching $file"
    cp -p "$file" "$file.fixed"
    sed -e 's| -DNDEBUG||g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"

    cp -p "$file" "$file.fixed"
    sed -e 's|$(cipher_openssl_compat_LDADD) $(LIBS)|$(cipher_openssl_compat_LDADD) $(LIBS) -lcrypto|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

echo "Patching Makefiles"
for file in $(find "$PWD" -iname 'Makefile')
do
    # Make console output more readable...
    cp -p "$file" "$file.fixed"
    sed -e 's|-Wtype-limits .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    cp -p "$file" "$file.fixed"
    sed -e 's|-fno-common .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

echo "Patching La files"
for file in $(find "$PWD" -iname '*.la')
do
    # Make console output more readable...
    cp -p "$file" "$file.fixed"
    sed -e 's|-Wtype-limits .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    cp -p "$file" "$file.fixed"
    sed -e 's|-fno-common .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

echo "Patching Shell Scripts"
for file in $(find "$PWD" -name '*.sh')
do
    # Fix shell
    cp -p "$file" "$file.fixed"
    sed -e 's|#!/bin/sh|#!/usr/bin/env bash|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

echo "Patching common,sh"
if [[ "$IS_SOLARIS" -ne 0 ]]
then
    # Fix shell script
    file=tests/scripts/common.sh
    cp -p "$file" "$file.fixed"
    sed -e 's|PFCMD -anl|PFCMD -an|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GnuTLS"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test GnuTLS"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test GnuTLS"
    exit 1
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

    ARTIFACTS=("$GNUTLS_XZ" "$GNUTLS_TAR" "$GNUTLS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-gnutls.sh 2>&1 | tee build-gnutls.log
    if [[ -e build-gnutls.log ]]; then
        rm -f build-gnutls.log
    fi

    unset SUDO_PASSWORD
fi

exit 0
