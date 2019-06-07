#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script cleans artifacts created by the Build Scripts
# If you installed something in a non-standard location, then
# you will need to delete it manually.

# Run the script like so:
#
#    sudo ./clean-build-scripts.sh

rm -rf ~/.cacert
rm -rf ~/.build-scripts
rm -rf ~/bootstrap
rm -rf ~/usr/local
