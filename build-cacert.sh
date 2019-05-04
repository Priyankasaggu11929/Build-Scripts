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
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Perform this action automatically for the user.
# setup-cacert.sh writes the certs locally for the user so
# we can download cacerts.pem from cURL. build-cacert.sh
# installs cacerts.pem in ${SH_CACERT_PATH}. Programs like
# cURL, Git and Wget use cacerts.pem.
if [[ ! -f "$HOME/.cacert/cacert.pem" ]]; then
    # Hide output to cut down on noise.
    ./setup-cacerts.sh &>/dev/null
fi

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    #echo ""
    #echo "$PKG_NAME is already installed."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
fi

###############################################################################

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./setup-password.sh
fi

###############################################################################
CACERT_FILE=$(basename "$SH_CACERT_FILE")
"$WGET" -q --ca-certificate="$GLOBALSIGN_ROOT" https://curl.haxx.se/ca/cacert.pem -O "$CACERT_FILE"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to download $CACERT_FILE"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -s "$CACERT_FILE" ]]
then
    if [[ "%IS_DARWIN" -ne 0 ]]; then
        ROOT_USR=root
        ROOT_GRP=wheel
    elif [[ "%IS_SOLARIS" -ne 0 ]]; then
        ROOT_USR=root
        ROOT_GRP=sys
    else
        ROOT_USR=root
        ROOT_GRP=root
    fi

    if [[ ! (-z "$SUDO_PASSWORD") ]]; then
        echo "$SUDO_PASSWORD" | sudo -S mkdir -p "$SH_CACERT_PATH"
        echo "$SUDO_PASSWORD" | sudo -S mv cacert.pem "$SH_CACERT_FILE"
        echo "$SUDO_PASSWORD" | sudo -S chown "$ROOT_USR:$ROOT_GRP" "$SH_CACERT_PATH"
        echo "$SUDO_PASSWORD" | sudo -S chmod 644 "$SH_CACERT_FILE"
        echo "$SUDO_PASSWORD" | sudo -S chown "$ROOT_USR:$ROOT_GRP" "$SH_CACERT_FILE"
    else
        mkdir -p "$SH_CACERT_PATH"
        cp "$CACERT_FILE" "$SH_CACERT_FILE"
        chmod 644 "$SH_CACERT_FILE"
    fi
fi

###############################################################################

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"
echo ""

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
