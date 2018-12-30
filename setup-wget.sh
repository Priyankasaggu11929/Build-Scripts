#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and OpenSSL from sources.

THIS_DIR=$(pwd)
function finish {
  cd "$THIS_DIR"
}
trap finish EXIT

# Bootstrap directory has OpenSSL and Wget
cd "bootstrap"

if ! ./wget.sh; then
    echo "Bootstrap failed for Wget"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
