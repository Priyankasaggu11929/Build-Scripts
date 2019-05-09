#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script writes several files needed by DNSSEC
# and libraries like Unbound and LDNS.

PKG_NAME=rootkey

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

ANY_FAIL=0
ROOT_KEY=$(basename "$SH_UNBOUND_ROOTKEY_FILE")
ICANN_BUNDLE=$(basename "$SH_UNBOUND_CACERT_FILE")

if [[ -e "$INSTX_PREFIX/sbin/unbound-anchor" ]]; then
    UNBOUND_ANCHOR="$INSTX_PREFIX/sbin/unbound-anchor"
else
    UNBOUND_ANCHOR="/sbin/unbound-anchor"
fi

###############################################################################

"$UNBOUND_ANCHOR" -a "$ROOT_KEY" -u data.iana.org

if [[ -d /private/etc ]]
then
    ROOT_USR=$(ls -ld /private/etc | head -n 1 | awk 'NR==1 {print $3}')
    ROOT_GRP=$(ls -ld /private/etc | head -n 1 | awk 'NR==1 {print $4}')
else
    ROOT_USR=$(ls -ld /etc | head -n 1 | awk 'NR==1 {print $3}')
    ROOT_GRP=$(ls -ld /etc | head -n 1 | awk 'NR==1 {print $4}')
fi

if [[ -s "$ROOT_KEY" ]]
then
    echo ""
    echo "Installing $SH_UNBOUND_ROOTKEY_FILE"
    if [[ -n "$SUDO_PASSWORD" ]]
    then
        echo "$SUDO_PASSWORD" | sudo -S mkdir -p "$SH_UNBOUND_ROOTKEY_PATH"
        echo "$SUDO_PASSWORD" | sudo -S mv "$ROOT_KEY" "$SH_UNBOUND_ROOTKEY_FILE"
        echo "$SUDO_PASSWORD" | sudo -S chown "$ROOT_USR":"$ROOT_GRP" "$SH_UNBOUND_ROOTKEY_PATH"
        echo "$SUDO_PASSWORD" | sudo -S chmod 644 "$SH_UNBOUND_ROOTKEY_FILE"
        echo "$SUDO_PASSWORD" | sudo -S chown "$ROOT_USR":"$ROOT_GRP" "$SH_UNBOUND_ROOTKEY_FILE"
    else
        mkdir -p "$SH_UNBOUND_ROOTKEY_PATH"
        cp "$ROOT_KEY" "$SH_UNBOUND_ROOTKEY_FILE"
        chmod 644 "$SH_UNBOUND_ROOTKEY_FILE"
    fi
else
    ANY_FAIL=1
    echo "Failed to download $ROOT_KEY"
fi

###############################################################################

echo
echo "********** ICANN Root Certs **********"
echo

if ! "$WGET" -O "$ICANN_BUNDLE" --ca-certificate="$CA_ZOO" \
     "https://data.iana.org/root-anchors/icannbundle.pem"
then
    echo "Failed to download icannbundle.pem"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -s "$ICANN_BUNDLE" ]]
then
    echo ""
    echo "Installing $SH_UNBOUND_CACERT_FILE"
    if [[ -n "$SUDO_PASSWORD" ]]
    then
        echo "$SUDO_PASSWORD" | sudo -S mkdir -p "$SH_UNBOUND_CACERT_PATH"
        echo "$SUDO_PASSWORD" | sudo -S mv "$ICANN_BUNDLE" "$SH_UNBOUND_CACERT_FILE"
        echo "$SUDO_PASSWORD" | sudo -S chown "$ROOT_USR":"$ROOT_GRP" "$SH_UNBOUND_CACERT_PATH"
        echo "$SUDO_PASSWORD" | sudo -S chmod 644 "$SH_UNBOUND_CACERT_FILE"
        echo "$SUDO_PASSWORD" | sudo -S chown "$ROOT_USR":"$ROOT_GRP" "$SH_UNBOUND_CACERT_FILE"
    else
        mkdir -p "$SH_UNBOUND_CACERT_PATH"
        cp "$ICANN_BUNDLE" "$SH_UNBOUND_CACERT_FILE"
        chmod 644 "$SH_UNBOUND_CACERT_FILE"
    fi
else
    ANY_FAIL=1
    echo "Failed to download $ICANN_BUNDLE"
fi

###############################################################################

echo ""
echo "*****************************************************************************"
echo "You should create a cron job that runs unbound-anchor on a"
echo "regular basis to update $SH_UNBOUND_ROOTKEY_FILE"
echo "*****************************************************************************"
echo ""

###############################################################################

if [[ "$ANY_FAIL" -ne 0 ]]; then
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
