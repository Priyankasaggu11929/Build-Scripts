#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and its dependencies from sources.

# This is the "compact" version of Wget without the extra dependencies
# or self tests. On really old systems you will have to run this first
# to get a working Wget. Once you bootstrap Wget you can build the full
# Wget version.

WGET_TAR=wget-1.19.5.tar.gz
WGET_DIR=wget-1.19.5
WGET_SHA1="43b3d09e786df9e8d7aa454095d4ea2d420ae41c"

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=4}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./build-environ.sh
then
    echo "Failed to set environment"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

echo
echo "********** Wget **********"
echo

# HTTP is probably the only way to bootstrap if the existing Wget is
# too old. We check the tarball hash for this case. Once we bootstrap
# Wget with OpenSSL we can use digital signatures.
"$WGET" "http://ftp.gnu.org/pub/gnu//wget/$WGET_TAR" -O "$WGET_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Wget"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Verify the hash if shasum is available
if [[ ! -z $(command -v shasum) ]]; then
    THIS_HASH=$(shasum "$WGET_TAR" 2>/dev/null | cut -d ' ' -f 1 | tr '[:upper:]' '[:lower:]')
    if [[ "$THIS_HASH" != "$WGET_SHA1" ]]; then
        echo "Failed to verify Wget download"
        echo "Expected: $WGET_SHA1"
        echo "Calculated: $THIS_HASH"
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
else
    echo "Failed to verify Wget download. Please install shasum"
fi

rm -rf "$WGET_DIR" &>/dev/null
gzip -d < "$WGET_TAR" | tar xf -
cd "$WGET_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

sed -e 's|$(LTLIBICONV)|$(LIBICONV)|g' fuzz/Makefile.am > fuzz/Makefile.am.fixed
mv fuzz/Makefile.am.fixed fuzz/Makefile.am
touch -t 197001010000 fuzz/Makefile.am

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --sysconfdir="$INSTX_PREFIX/etc" \
    --with-ssl=openssl \
    --without-zlib \
    --without-libpsl \
    --without-libuuid \
    --without-libidn

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Wget"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS" "all")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Wget"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Wget does not have any CA's configured at the moment. HTTPS downloads
# will fail with the message "... use --no-check-certifcate ...". Fix it
# through the system's wgetrc configuration file.
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "Copying new-cacert.pem to $SH_CACERT_PATH"
    echo "$SUDO_PASSWORD" | sudo -S cp "$HOME/.cacert/cacert.pem" "$SH_CACERT_PATH/new-cacert.pem"

    cp "./doc/sample.wgetrc" "./wgetrc"
    echo "" >> "./wgetrc"
    echo "# Default CA zoo file added by Build-Scripts" >> "./wgetrc"
    echo "ca_certificate = $SH_CACERT_PATH/new-cacert.pem" >> "./wgetrc"

    echo "$SUDO_PASSWORD" | sudo -S cp "./wgetrc" "$INSTX_PREFIX/etc/wgetrc"
else
    cp "./doc/sample.wgetrc" "./wgetrc"
    echo "" >> "./wgetrc"
    echo "# Default CA zoo file added by Build-Scripts" >> "./wgetrc"
    echo "ca_certificate = $HOME/.cacert/cacert.pem" >> "./wgetrc"
    cp "./wgetrc" "$HOME/.wgetrc"
fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

# Remove previous build stamp so the library is rebuilt
rm -f "$INSTX_CACHE/wget"

cd "$CURR_DIR"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "A compact version of Wget was installed to allow downloading dependencies."
echo "You should run build-wget.sh next to build a full version with dependencies."
echo "*****************************************************************************"
echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$WGET_TAR" "$WGET_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-wget.sh 2>&1 | tee build-wget.log
    if [[ -e build-wget.log ]]; then
        rm -f build-wget.log
    fi

    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
