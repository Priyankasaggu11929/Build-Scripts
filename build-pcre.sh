#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds PCRE and PCRE2 from sources.

PCRE_TAR=pcre-8.43.tar.gz
PCRE_DIR=pcre-8.43
PKG_NAME1=pcre

PCRE2_TAR=pcre2-10.32.tar.gz
PCRE2_DIR=pcre2-10.32
PKG_NAME2=pcre2

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

if [[ -e "$INSTX_CACHE/$PKG_NAME1" && -e "$INSTX_CACHE/$PKG_NAME2" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME1 and $PKG_NAME2 are already installed."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
fi

# The password should die when this subshell goes out of scope
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

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** PCRE **********"
echo

# This fails when Wget < 1.14
echo "Attempting download PCRE using HTTPS."
"$WGET" --ca-certificate="$IDENTRUST_ROOT" "https://ftp.pcre.org/pub/pcre/$PCRE_TAR" -O "$PCRE_TAR"

# This is due to the way Wget calls OpenSSL. The OpenSSL context
# needs OPT_V_PARTIAL_CHAIN option. The option says "Root your
# trust in this certificate; and not a self-signed CA root."
if [[ "$?" -ne 0 ]]; then
    echo "Attempting download PCRE using insecure channel."
    "$WGET" --no-check-certificate "https://ftp.pcre.org/pub/pcre/$PCRE_TAR" -O "$PCRE_TAR"
fi

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download PCRE"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$PCRE_DIR" &>/dev/null
gzip -d < "$PCRE_TAR" | tar xf -
cd "$PCRE_DIR"

cp ../patch/pcre.patch .
patch -u -p0 < pcre.patch
echo ""

# Our grep catches 'runtime error' and signals failure.
# We a source code comment, but it is present in the patch.
rm pcre.patch

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared --enable-pcregrep-libz --enable-jit --enable-pcregrep-libbz2

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure PCRE"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS" "all" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build PCRE"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ "$IS_LINUX" -ne 0 ]]; then
	MAKE_FLAGS=("check" "V=1")
	if ! "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test PCRE"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
fi

# https://bugs.exim.org/show_bug.cgi?id=2380
echo "Searching for errors hidden in log files"
COUNT=$(grep -oIR 'runtime error' | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test PCRE"
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
touch "$INSTX_CACHE/$PKG_NAME1"

###############################################################################

echo
echo "********** PCRE2 **********"
echo

# This fails when Wget < 1.14
echo "Attempting download PCRE2 using HTTPS."
"$WGET" --ca-certificate="$IDENTRUST_ROOT" "https://ftp.pcre.org/pub/pcre/$PCRE2_TAR" -O "$PCRE2_TAR"

# This is due to the way Wget calls OpenSSL. The OpenSSL context
# needs OPT_V_PARTIAL_CHAIN option. The option says "Root your
# trust in this certificate; and not a self-signed CA root."
if [[ "$?" -ne 0 ]]; then
    echo "Attempting download PCRE2 using insecure channel."
    "$WGET" --no-check-certificate "https://ftp.pcre.org/pub/pcre/$PCRE2_TAR" -O "$PCRE2_TAR"
fi

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$PCRE2_DIR" &>/dev/null
gzip -d < "$PCRE2_TAR" | tar xf -
cd "$PCRE2_DIR"

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --enable-shared --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS" "all" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ "$IS_LINUX" -ne 0 ]]; then
	MAKE_FLAGS=("check" "V=1")
	if ! "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test PCRE"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
fi

echo "Searching for errors hidden in log files"
COUNT=$(grep -oIR 'runtime error' | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test PCRE2"
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
touch "$INSTX_CACHE/$PKG_NAME2"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$PCRE_TAR" "$PCRE_DIR" "$PCRE2_TAR" "$PCRE2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-pcre.sh 2>&1 | tee build-pcre.log
    if [[ -e build-pcre.log ]]; then
        rm -f build-pcre.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
