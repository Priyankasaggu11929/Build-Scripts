#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Emacs and its dependencies from sources.

EMACS_TAR=emacs-26.2.tar.gz
EMACS_DIR=emacs-26.2

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
    source ./setup-password.sh
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

if false; then

if ! ./build-ncurses.sh
then
    echo "Failed to build Ncurses"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

fi

###############################################################################

echo
echo "********** Emacs **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://ftp.gnu.org/gnu/emacs/$EMACS_TAR" -O "$EMACS_TAR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download Emacs"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$EMACS_DIR" &>/dev/null
gzip -d < "$EMACS_TAR" | tar xf -
cd "$EMACS_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

EMACS_OPTS=('--with-xml2' '--without-x' '--without-sound' '--without-xpm'
    '--without-jpeg' '--without-tiff' '--without-gif' '--without-png'
    '--without-rsvg' '--without-imagemagick' '--without-xft' '--without-libotf'
    '--without-m17n-flt' '--without-xaw3d' '--without-toolkit-scroll-bars'
    '--without-gpm' '--without-dbus' '--without-gconf' '--without-gsettings'
    '--without-makeinfo' '--without-compress-install' '--with-gnutls=no')

if [[ ! -e "/usr/include/selinux/context.h" ]] &&
   [[ ! -e "/usr/local/include/selinux/context.h" ]]; then
    EMACS_OPTS+=('--without-selinux')
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    "${EMACS_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure emacs"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "Fixing CHAR_WIDTH macro"
for sfile in $(grep -IR 'CHAR_WIDTH' * | cut -f 1 -d ':' | uniq); do
    sed -e 's|CHAR_WIDTH|CHARACTER_WIDTH|g' "$sfile" > "$sfile.fixed"
    mv "$sfile.fixed" "$sfile"
done

#MAKE_FLAGS=("check" "V=1")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#   echo "Failed to test Emacs"
#   [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
#fi

#echo "Searching for errors hidden in log files"
#COUNT=$(grep -oIR 'runtime error:' ./* | wc -l)
#if [[ "${COUNT}" -ne 0 ]];
#then
#    echo "Failed to test Emacs"
#    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
#fi

MAKE_FLAGS=("-j" "$INSTX_JOBS" "all")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build emacs"
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

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$EMACS_TAR" "$EMACS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-emacs.sh 2>&1 | tee build-emacs.log
    if [[ -e build-emacs.log ]]; then
        rm -f build-emacs.log
    fi

    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
