#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and OpenSSL from sources.

CURR_DIR=$(pwd)
function finish {
  cd "$CURR_DIR"
}
trap finish EXIT

# Bootstrap directory has OpenSSL and Wget
cd "bootstrap"

if ! ./bootstrap-wget.sh; then
    echo "Bootstrap failed for Wget"
    exit 1
fi

exit 0
