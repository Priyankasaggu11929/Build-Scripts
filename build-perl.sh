#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Perl from sources.

PERL_TAR=perl-5.28.2.tar.gz
PERL_DIR=perl-5.28.2

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

# The password should die when this subshell goes out of scope
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
echo "********** Perl **********"
echo

if ! "$WGET" -O "$PERL_TAR" --ca-certificate="$GLOBALSIGN_ROOT" \
     "http://www.cpan.org/src/5.0/$PERL_TAR"
then
    echo "Failed to download Perl"
    exit 1
fi

rm -rf "$PERL_DIR" &>/dev/null
gzip -d < "$PERL_TAR" | tar xf -
cd "$PERL_DIR"

if ! ./Configure -des -Dextras="HTTP::Daemon HTTP::Request Test::More Text::Template"
then
    echo "Failed to configure Perl"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Perl"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=(check)
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Perl"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Perl"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

# This downloads and installs Perl's package manager
# curl -L http://cpanmin.us | perl - App::cpanminus

cd "$CURR_DIR"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$PERL_TAR" "$PERL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-perl.sh 2>&1 | tee build-perl.log
    if [[ -e build-perl.log ]]; then
        rm -f build-perl.log
    fi
fi

exit 0
