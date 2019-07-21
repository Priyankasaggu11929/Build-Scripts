#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Bzip2 from sources.

# Bzip lost its website. It is now located on Sourceware.

BZIP2_TAR=bzip2-1.0.8.tar.gz
BZIP2_DIR=bzip2-1.0.8
PKG_NAME=bzip2

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

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
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

echo
echo "********** Bzip **********"
echo

if ! "$WGET" -O "$BZIP2_TAR" \
     "ftp://sourceware.org/pub/bzip2/$BZIP2_TAR"
then
    echo "Failed to download Bzip"
    exit 1
fi

rm -rf "$BZIP2_DIR" &>/dev/null
gzip -d < "$BZIP2_TAR" | tar xf -
cd "$BZIP2_DIR"

#cp Makefile Makefile.orig
#cp Makefile-libbz2_so Makefile-libbz2_so.orig
#exit 1

cp ../patch/bzip.patch .
patch -u -p0 < bzip.patch
echo ""

# Fix format specifier.
# TODO: fix this in the source code.
if [[ "$IS_64BIT" -ne 0 ]]; then
    for cfile in $(find "$PWD" -name '*.c'); do
        sed -e "s|%Lu|%llu|g" "$cfile" > "$cfile.fixed"
        mv "$cfile.fixed" "$cfile"
    done
fi

echo "**********************"
echo "Building package"
echo "**********************"

if [[ "$IS_DARWIN" -ne 0 ]]; then
    BZIP_SONAME_SHRT="libbz2.1.0.dylib"
    BZIP_SONAME_LONG="libbz2.1.0.8.dylib"
    BZIP_SHARED_OPT="-dynamiclib"
    BZIP_SONAME_OPT="-Wl,-install_name,$BZIP_SONAME_LONG"
else
    BZIP_SONAME_SHRT="libbz2.1.0.so"
    BZIP_SONAME_LONG="libbz2.1.0.8.so"
    BZIP_SHARED_OPT="-shared"
    BZIP_SONAME_OPT="-Wl,-soname,$BZIP_SONAME_SHRT"
fi

MAKE_FLAGS=("-f" "Makefile"
            "-j" "$INSTX_JOBS"
            CC="${CC}"
            CFLAGS="${BUILD_CFLAGS[*]} -I."
            LDFLAGS="${BUILD_LDFLAGS[*]}"
            BZIP_SONAME_SHRT="$BZIP_SONAME_SHRT"
            BZIP_SONAME_LONG="$BZIP_SONAME_LONG"
            BZIP_SHARED_OPT="$BZIP_SHARED_OPT"
            BZIP_SONAME_OPT="$BZIP_SONAME_OPT")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip"
    exit 1
fi

MAKE_FLAGS=("-f" "Makefile-libbz2_so"
            "-j" "$INSTX_JOBS"
            CC="${CC}"
            CFLAGS="${BUILD_CFLAGS[*]} -I."
            LDFLAGS="${BUILD_LDFLAGS[*]}"
            BZIP_SONAME_SHRT="$BZIP_SONAME_SHRT"
            BZIP_SONAME_LONG="$BZIP_SONAME_LONG"
            BZIP_SHARED_OPT="$BZIP_SHARED_OPT"
            BZIP_SONAME_OPT="$BZIP_SONAME_OPT")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("-f" "Makefile"
            "check"
            "-j" "$INSTX_JOBS"
            CC="${CC}"
            CFLAGS="${BUILD_CFLAGS[*]} -I."
            LDFLAGS="${BUILD_LDFLAGS[*]}")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Bzip"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

if [[ -n "$SUDO_PASSWORD" ]]; then
    MAKE_FLAGS=("-f" "Makefile"
                install
                BINDIR="$INSTX_PREFIX/bin"
                LIBDIR="$INSTX_LIBDIR"
                BZIP_SONAME_SHRT="$BZIP_SONAME_SHRT"
                BZIP_SONAME_LONG="$BZIP_SONAME_LONG"
                BZIP_SHARED_OPT="$BZIP_SHARED_OPT"
                BZIP_SONAME_OPT="$BZIP_SONAME_OPT")
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"

    MAKE_FLAGS=("-f" "Makefile-libbz2_so"
                install
                BINDIR="$INSTX_PREFIX/bin"
                LIBDIR="$INSTX_LIBDIR"
                BZIP_SONAME_SHRT="$BZIP_SONAME_SHRT"
                BZIP_SONAME_LONG="$BZIP_SONAME_LONG"
                BZIP_SHARED_OPT="$BZIP_SHARED_OPT"
                BZIP_SONAME_OPT="$BZIP_SONAME_OPT")
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    MAKE_FLAGS=("-f" "Makefile"
                install
                BINDIR="$INSTX_PREFIX/bin"
                LIBDIR="$INSTX_LIBDIR"
                BZIP_SONAME_SHRT="$BZIP_SONAME_SHRT"
                BZIP_SONAME_LONG="$BZIP_SONAME_LONG"
                BZIP_SONAME_OPT="$BZIP_SONAME_OPT")
    "$MAKE" "${MAKE_FLAGS[@]}"

    MAKE_FLAGS=("-f" "Makefile-libbz2_so"
                install
                BINDIR="$INSTX_PREFIX/bin"
                LIBDIR="$INSTX_LIBDIR"
                BZIP_SONAME_SHRT="$BZIP_SONAME_SHRT"
                BZIP_SONAME_LONG="$BZIP_SONAME_LONG"
                BZIP_SHARED_OPT="$BZIP_SHARED_OPT"
                BZIP_SONAME_OPT="$BZIP_SONAME_OPT")
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

    ARTIFACTS=("$BZIP2_TAR" "$BZIP2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-bzip.sh 2>&1 | tee build-bzip.log
    if [[ -e build-bzip.log ]]; then
        rm -f build-bzip.log
    fi
fi

exit 0
