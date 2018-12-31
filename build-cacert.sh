#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script writes several Root CA certifcates needed
# for other scripts and wget downloads over HTTPS.

PKG_NAME=cacert

###############################################################################

CURR_DIR=$(pwd)
function finish {
  cd "$CURR_DIR"
}
trap finish EXIT

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./build-environ.sh
then
    echo "Failed to set environment"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

GLOBALSIGN_ROOT="$HOME/.cacert/globalsign-root-r1.pem"
if [[ ! -f "$GLOBALSIGN_ROOT" ]]; then
    echo "cURL requires several CA roots. Please run build-cacerts.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
fi

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

"$WGET" -q --ca-certificate="$GLOBALSIGN_ROOT" https://curl.haxx.se/ca/cacert.pem -O cacert.pem

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download cacert.pem"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S mkdir -p "$SH_CACERT_PATH"
    echo "$SUDO_PASSWORD" | sudo -S cp cacert.pem "$SH_CACERT_FILE"
    echo "$SUDO_PASSWORD" | sudo -S chmod 644 "$SH_CACERT_FILE"
else
    mkdir -p "$SH_CACERT_PATH"
    cp cacert.pem "$SH_CACERT_FILE"
    chmod 644 "$SH_CACERT_FILE"
fi

###############################################################################

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

rm cacert.pem

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
