#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GnuTLS and its dependencies from sources.

GNUTLS_TAR=gnutls-3.6.6.tar.xz
GNUTLS_DIR=gnutls-3.6.6
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

if ! ./build-tasn1.sh
then
    echo "Failed to build Tasn1"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-gmp.sh
then
    echo "Failed to build GMP"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-nettle.sh
then
    echo "Failed to build Nettle"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-ncurses.sh
then
    echo "Failed to build ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-iconv.sh
then
    echo "Failed to build iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-expat.sh
then
    echo "Failed to build Expat"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-unbound.sh
then
    echo "Failed to build Unbound"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-readline.sh
then
    echo "Failed to build Readline"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-p11kit.sh
then
    echo "Failed to build P11-Kit"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-guile.sh
then
    echo "Failed to build Guile"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** GnuTLS **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.6/$GNUTLS_TAR" -O "$GNUTLS_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download GnuTLS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$GNUTLS_DIR" &>/dev/null
tar xJf "$GNUTLS_TAR"
cd "$GNUTLS_DIR"

#cp ../patch/gnutls.patch .
#patch -u -p0 < gnutls.patch
#echo ""

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

# I cringe over this due to the patch
autoreconf

# Solaris is a tab bit stricter than libc
if [[ "$IS_SOLARIS" -eq 1 ]]; then
    # Don't use CPPFLAGS. _XOPEN_SOURCE will cross-pollinate into CXXFLAGS.
    BUILD_CFLAGS+=("-D_XOPEN_SOURCE=600 -std=c99")
    BUILD_CXXFLAGS+=("-std=c++03")
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="-lhogweed -lnettle -lgmp ${BUILD_LIBS[*]}" \
./configure --enable-shared --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --with-unbound-root-key-file --enable-seccomp-tests \
    --disable-openssl-compatibility --disable-ssl2-support --disable-ssl3-support \
    --disable-gtk-doc --disable-gtk-doc-html --disable-gtk-doc-pdf \
    --with-p11-kit --with-tpm --with-libregex \
    --with-libz-prefix="$INSTX_PREFIX" \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libintl-prefix="$INSTX_PREFIX" \
    --with-libseccomp-prefix="$INSTX_PREFIX" \
    --with-libunistring-prefix="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure GnuTLS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Test suite does not compile with NDEBUG defined. Configure
# does not provide option for separate CFLAGS or CXXFLAGS.
# Makefile does not honor CFLAGS or CXXFLAGS on command line.
for file in $(find "$PWD/tests" -iname 'Makefile')
do
	echo "Patching $file"
    sed -e 's| -DNDEBUG||g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

MAKE_FLAGS=("-j" "$INSTX_JOBS" "all" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GnuTLS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ "$IS_DARWIN" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! DYLD_LIBRARY_PATH="lib/.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test GnuTLS"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
elif [[ "$IS_LINUX" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! LD_LIBRARY_PATH="lib/.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test GnuTLS"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
else
	MAKE_FLAGS=("check" "V=1")
	if ! "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test GnuTLS"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
fi

echo "Searching for errors hidden in log files"
COUNT=$(grep -oIR 'runtime error' | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test GnuTLS"
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

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$GNUTLS_TAR" "$GNUTLS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-gnutls.sh 2>&1 | tee build-gnutls.log
    if [[ -e build-gnutls.log ]]; then
        rm -f build-gnutls.log
    fi

    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
