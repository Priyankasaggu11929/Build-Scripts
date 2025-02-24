#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds SSH and its dependencies from sources.

OPENSSH_TAR=openssh-8.0p1.tar.gz
OPENSSH_DIR=openssh-8.0p1

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

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./setup-password.sh
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

if ! ./build-ldns.sh
then
    echo "Failed to build LDNS"
    exit 1
fi

###############################################################################

echo
echo "********** OpenSSH **********"
echo

if ! "$WGET" -O "$OPENSSH_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "http://ftp4.usa.openbsd.org/pub/OpenBSD/OpenSSH/portable/$OPENSSH_TAR"
then
    echo "Failed to download SSH"
    exit 1
fi

rm -rf "$OPENSSH_DIR" &>/dev/null
gzip -d < "$OPENSSH_TAR" | tar xf -
cd "$OPENSSH_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_CFLAGS[*]} ${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --with-cppflags="${BUILD_CPPFLAGS[*]}" \
    --with-cflags="${BUILD_CFLAGS[*]}" \
    --with-ldflags="${BUILD_CFLAGS[*]} ${BUILD_LDFLAGS[*]}" \
    --with-libs="-lz ${BUILD_LIBS[*]}"\
    --with-zlib="$INSTX_PREFIX" \
    --with-ssl-dir="$INSTX_PREFIX" \
    --with-ldns="$INSTX_PREFIX" \
    --with-pie \
    --disable-strip

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure SSH"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build SSH"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

echo
echo "Unable to test OpenSSH"
echo 'https://groups.google.com/forum/#!topic/mailing.unix.openssh-dev/srdwaPQQ_Aw'
echo

# No way to test OpenSSH after build...
# https://groups.google.com/forum/#!topic/mailing.unix.openssh-dev/srdwaPQQ_Aw
#MAKE_FLAGS=("check" "V=1")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test SSH"
#    exit 1
#fi

#echo "Searching for errors hidden in log files"
#COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
#if [[ "${COUNT}" -ne 0 ]];
#then
#    echo "Failed to test SSH"
#    exit 1
#fi

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

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$OPENSSH_TAR" "$OPENSSH_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openssh.sh 2>&1 | tee build-openssh.log
    if [[ -e build-openssh.log ]]; then
        rm -f build-openssh.log
    fi
fi

exit 0
