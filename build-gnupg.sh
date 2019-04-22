
#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GnuPG and its dependencies from sources.

GNUPG_TAR=gnupg-2.2.13.tar.bz2
GNUPG_DIR=gnupg-2.2.13
PKG_NAME=gnupg

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

if ! ./build-iconv.sh
then
    echo "Failed to build iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-tasn1.sh
then
    echo "Failed to build libtasn1"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

# Need gnulib for intl.h
#if ! ./build-libintl.sh
#then
#    echo "Failed to build libintl"
#    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
#fi

###############################################################################

if ! ./build-gpgerror.sh
then
    echo "Failed to build Libgpg-error"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-libksba.sh
then
    echo "Failed to build Libksba"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-libassuan.sh
then
    echo "Failed to build Libassuan"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-libgcrypt.sh
then
    echo "Failed to build Libgcrypt"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-ntbTLS.sh
then
    echo "Failed to build ntbTLS"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-nPth.sh
then
    echo "Failed to build nPth"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** GnuPG **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://gnupg.org/ftp/gcrypt/gnupg/$GNUPG_TAR" -O "$GNUPG_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download GnuPG"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$GNUPG_DIR" &>/dev/null
tar xjf "$GNUPG_TAR"
cd "$GNUPG_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

# Solaris is a tab bit stricter than libc
#if [[ "$IS_SOLARIS" -eq 1 ]]; then
#    # Don't use CPPFLAGS. _XOPEN_SOURCE will cross-pollinate into CXXFLAGS.
#    BUILD_CFLAGS+=("-D_XOPEN_SOURCE=600 -std=c99")
#    BUILD_CXXFLAGS+=("-std=c++03")
#fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --disable-scdaemon \
    --disable-dirmngr \
    --disable-wks-tools \
    --disable-doc \
	--with-libgpg-error-prefix="$INSTX_PREFIX" \
    --with-libgcrypt-prefix="$INSTX_PREFIX" \
    --with-libassuan-prefix="$INSTX_PREFIX" \
    --with-ksba-prefix=PFX="$INSTX_PREFIX" \
    --with-npth-prefix=PFX="$INSTX_PREFIX" \
    --with-ntbtls-prefix="$INSTX_PREFIX" \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libintl-prefix="$INSTX_PREFIX" \
    --with-zlib="$INSTX_PREFIX" \
    --with-bzip2="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure GnuPG"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

cp ../patch/gnupg.patch .
patch -u -p0 < gnupg.patch

MAKE_FLAGS=("-j" "$INSTX_JOBS" "all")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GnuPG"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ "$IS_DARWIN" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! DYLD_LIBRARY_PATH="./.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test GnuPG"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
elif [[ "$IS_LINUX" -ne 0 ]];
then
	MAKE_FLAGS=("check" "V=1")
	if ! LD_LIBRARY_PATH="./.libs" "$MAKE" "${MAKE_FLAGS[@]}"
	then
		echo "Failed to test GnuPG"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
fi

echo "Searching for errors hidden in log files"
COUNT=$(grep -oIR 'runtime error:' | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test GnuPG"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$GNUPG_TAR" "$GNUPG_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-gnupg.sh 2>&1 | tee build-gnupg.log
    if [[ -e build-gnupg.log ]]; then
        rm -f build-gnupg.log
    fi

    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
