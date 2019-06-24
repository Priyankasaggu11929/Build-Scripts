#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and its dependencies from sources.

WGET_TAR=wget-1.20.3.tar.gz
WGET_DIR=wget-1.20.3

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

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./setup-password.sh
fi

###############################################################################

# Optional. For Solaris see https://community.oracle.com/thread/1915569.
SKIP_WGET_TESTS=0
if [[ -z $(command -v python) ]]; then
    SKIP_WGET_TESTS=1
else
    if ! perl -MHTTP::Daemon -e1 2>/dev/null
    then
         echo ""
         echo "Wget requires Perl's HTTP::Daemon. Skipping Wget self tests."
         echo "To fix this issue, please install HTTP-Daemon."
         SKIP_WGET_TESTS=1
    fi

    if ! perl -MHTTP::Request -e1 2>/dev/null
    then
         echo ""
         echo "Wget requires Perl's HTTP::Request.  Skipping Wget self tests."
         echo "To fix this issue, please install HTTP-Request or HTTP-Message."
         SKIP_WGET_TESTS=1
    fi
fi

# PSL may be skipped if Python is too old. libpsl requires Python 2.7
# Also see https://stackoverflow.com/a/40950971/608639
SKIP_LIBPSL=1
if [[ -n $(command -v python) ]]; then
    ver=$(python -V 2>&1 | sed 's/.* \([0-9]\).\([0-9]\).*/\1\2/')
    if [ "$ver" -ge 27 ]; then
        SKIP_LIBPSL=0
    fi
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
    echo "Failed to build Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-idn2.sh
then
    echo "Failed to build IDN2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-cares.sh
then
    echo "Failed to build c-ares"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-pcre2.sh
then
    echo "Failed to build PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if [[ "$SKIP_LIBPSL" -eq 0 ]]; then

if ! ./build-libpsl.sh
then
    echo "Failed to build Public Suffix List library"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

fi  # SKIP_LIBPSL

###############################################################################

echo
echo "********** Wget **********"
echo

if ! "$WGET" -O "$WGET_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/wget/$WGET_TAR"
then
    echo "Failed to download Wget"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$WGET_DIR" &>/dev/null
gzip -d < "$WGET_TAR" | tar xf -
cd "$WGET_DIR"

echo "SKIP_WGET_TESTS: ${SKIP_WGET_TESTS}"
echo "SKIP_LIBPSL: ${SKIP_LIBPSL}"
echo ""

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

sed -e 's|$(LTLIBICONV)|$(LIBICONV)|g' fuzz/Makefile.am > fuzz/Makefile.am.fixed
mv fuzz/Makefile.am.fixed fuzz/Makefile.am
touch -t 197001010000 fuzz/Makefile.am

# https://lists.gnu.org/archive/html/bug-wget/2019-05/msg00064.html
for file in $(find "$PWD" -name '*.px')
do
    sed -e 's|env -S perl -I .|env perl|g' "$file" > "$file.fixed"
    chmod +w "$file"
    mv "$file.fixed" "$file"
    chmod +x "$file"
    chmod -w "$file"
done

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --sysconfdir="$INSTX_PREFIX/etc" \
    --with-ssl=openssl --with-libssl-prefix="$INSTX_PREFIX" \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libunistring-prefix="$INSTX_PREFIX" \
    --with-libidn="$INSTX_PREFIX" \
    --with-cares

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Wget"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Wget"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

if [[ "$SKIP_WGET_TESTS" -eq 0 ]]
then
    # Perl IPv6 may be broken and cause Wget self tests to fail.
    # Ignore failures about Socket::inet_itoa and incorrect sizes.
    # https://rt.cpan.org/Public/Bug/Display.html?id=91699
    # Perl does not include PWD so it compiles and executes
    # tests like Test-https-pfs.px, but fails to find
    # WgetFeature.pm which is located in the same directory.
    # I fail to see the difference in risk. How is
    # Test-https-pfs.px safe, but WgetFeature.pm dangerous?
    MAKE_FLAGS=("check" "V=1")
    if ! PERL_USE_UNSAFE_INC=1 "$MAKE" "${MAKE_FLAGS[@]}"
    then
        echo "Failed to test Wget"
        echo "Installing anyways..."
        #[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi

    echo "Searching for errors hidden in log files"
    COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
    if [[ "${COUNT}" -ne 0 ]];
    then
        echo "Failed to test Wget"
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
else
    echo "Wget not tested."
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

# Wget does not have any CA's configured at the moment. HTTPS downloads
# will fail with the message "... use --no-check-certifcate ...". Fix it
# through the system's wgetrc configuration file.
cp "./doc/sample.wgetrc" "./wgetrc"
echo "" >> "./wgetrc"
echo "# Default CA zoo file added by Build-Scripts" >> "./wgetrc"
echo "ca_directory = $SH_CACERT_PATH" >> "./wgetrc"
echo "ca_certificate = $SH_CACERT_FILE" >> "./wgetrc"

if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S mkdir -p "$INSTX_PREFIX/etc"
    echo "$SUDO_PASSWORD" | sudo -S cp "./wgetrc" "$INSTX_PREFIX/etc/"
else
    mkdir -p "$INSTX_PREFIX/etc"
    cp "./wgetrc" "$INSTX_PREFIX/etc/"
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
