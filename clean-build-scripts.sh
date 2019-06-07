#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script cleans artifacts created by the Build Scripts
# If you installed something in a non-standard location, then
# you will need to delete it manually.

# Run the script like so:
#
#    sudo ./clean-build-scripts.sh

rm -rf "$HOME/.cacert"
rm -rf "$HOME/.build-scripts"
rm -rf "$HOME/bootstrap"

if [[ -n "$INSTX_PREFIX" ]]; then
    rm -rf "$INSTX_PREFIX"
elif [[ "$EUID" -eq 0 ]]; then
    rm -rf ~/usr/local
fi
