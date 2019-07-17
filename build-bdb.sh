
#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds BerkleyDB from sources.

BDB_TAR=db-6.2.32.tar.gz
BDB_DIR=db-6.2.32
PKG_NAME=bdb

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

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

echo
echo "********** Berkely DB **********"
echo

cp "bootstrap/$BDB_TAR" .
rm -rf "$BDB_DIR" &>/dev/null
gzip -d < "$BDB_TAR" | tar xf -

cd "$BDB_DIR"

cp ../patch/db.patch .
patch -u -p0 < db.patch
echo ""

cd "$CURR_DIR"
cd "$BDB_DIR/dist"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../../fix-config.sh

cd "$CURR_DIR"
cd "$BDB_DIR/build_unix"

CONFIG_OPTS=()
CONFIG_OPTS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTS+=("--with-tls=openssl")

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
../dist/configure "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure BerkleyDB"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build BerkleyDB"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

echo "Unable to test Berkley DB"

# No check or test recipes
#MAKE_FLAGS=("check" "V=1")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test BerkleyDB"
#    exit 1
#fi

#echo "Searching for errors hidden in log files"
#COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
#if [[ "${COUNT}" -ne 0 ]];
#then
#    echo "Failed to test BerkleyDB"
#    exit 1
#fi

echo "**********************"
echo "Installing package"
echo "**********************"

echo "" > libdb.pc
echo "prefix=$INSTX_PREFIX" >> libdb.pc
echo "exec_prefix=\${prefix}" >> libdb.pc
echo "libdir=$INSTX_LIBDIR" >> libdb.pc
echo "includedir=\${prefix}/include" >> libdb.pc
echo "" >> libdb.pc
echo "Name: Berkley DB" >> libdb.pc
echo "Description: Berkley DB client library" >> libdb.pc
echo "Version: 6.2" >> libdb.pc
echo "" >> libdb.pc
echo "Requires:" >> libdb.pc
echo "Libs: -L\${libdir}" >> libdb.pc
echo "Cflags: -I\${includedir}" >> libdb.pc

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
    echo "$SUDO_PASSWORD" | sudo -S cp libdb.pc "$INSTX_LIBDIR/pkgconfig"
    echo "$SUDO_PASSWORD" | sudo -S chmod 644 "$INSTX_LIBDIR/pkgconfig/libdb.pc"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
    cp libdb.pc "$INSTX_LIBDIR/pkgconfig"
    chmod 644 "$INSTX_LIBDIR/pkgconfig/libdb.pc"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$BDB_TAR" "$BDB_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openldap.sh 2>&1 | tee build-openldap.log
    if [[ -e build-openldap.log ]]; then
        rm -f build-openldap.log
    fi

    unset SUDO_PASSWORD
fi

exit 0
