#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Bzip2 from sources.

# See fixup for INSTALL_LIBDIR below
INSTALL_PREFIX=/usr/local
INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"

BZIP2_TAR=bzip2-1.0.6.tar.gz
BZIP2_DIR=bzip2-1.0.6

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

# Sets the number of make jobs if not set in environment
: "${MAKE_JOBS:=4}"

###############################################################################

# Autotools on Solaris has an implied requirement for GNU gear. Things fall apart without it.
# Also see https://blogs.oracle.com/partnertech/entry/preparing_for_the_upcoming_removal.
if [[ -d "/usr/gnu/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/gnu/bin"*) ]]; then
        echo
        echo "Adding /usr/gnu/bin to PATH for Solaris"
        PATH="/usr/gnu/bin:$PATH"
    fi
elif [[ -d "/usr/swf/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/sfw/bin"*) ]]; then
        echo
        echo "Adding /usr/sfw/bin to PATH for Solaris"
        PATH="/usr/sfw/bin:$PATH"
    fi
elif [[ -d "/usr/ucb/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/ucb/bin"*) ]]; then
        echo
        echo "Adding /usr/ucb/bin to PATH for Solaris"
        PATH="/usr/ucb/bin:$PATH"
    fi
fi

###############################################################################

if [[ -z $(command -v gzip 2>/dev/null) ]]; then
    echo "Some packages gzip. Please install gzip."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

IS_DARWIN=$(uname -s | grep -i -c darwin)
if [[ ("$IS_DARWIN" -eq "0") ]] && [[ -z $(command -v libtoolize 2>/dev/null) ]]; then
    echo "Some packages require libtool. Please install libtool or libtool-bin."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v autoreconf 2>/dev/null) ]]; then
    echo "Some packages require autoreconf. Please install autoconf or automake."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ ! -f "$HOME/.cacert/lets-encrypt-root-x3.pem" ]]; then
    echo "zLib requires several CA roots. Please run build-cacert.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"

###############################################################################

THIS_SYSTEM=$(uname -s 2>&1)
IS_DARWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c darwin)
IS_SOLARIS=$(echo -n "$THIS_SYSTEM" | grep -i -c sunos)

# The BSDs and Solaris should have GMake installed if its needed
if [[ $(command -v gmake 2>/dev/null) ]]; then
    MAKE="gmake"
else
    MAKE="make"
fi

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32 and /usr/local/lib64
# The Autoconf programs misdetect Solaris as x86 even though its x64. OpenBSD has
# getconf, but it does not have LONG_BIT.
IS_64BIT=$(getconf LONG_BIT 2>&1 | grep -i -c 64)
if [[ "$IS_64BIT" -eq "0" ]]; then
    IS_64BIT=$(file /bin/ls 2>&1 | grep -i -c '64-bit')
fi

if [[ "$IS_SOLARIS" -ne "0" ]]; then
    SH_MARCH="-m64"
    INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
elif [[ "$IS_64BIT" -ne "0" ]]; then
    if [[ (-d /usr/lib) && (-d /usr/lib32) ]]; then
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
    elif [[ (-d /usr/lib) && (-d /usr/lib64) ]]; then
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib64"
    else
        SH_MARCH="-m64"
        INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
    fi
else
    SH_MARCH="-m32"
    INSTALL_LIBDIR="$INSTALL_PREFIX/lib"
fi

if [[ (-z "$CC" && $(command -v cc 2>/dev/null) ) ]]; then CC=$(command -v cc); fi
if [[ (-z "$CXX" && $(command -v CC 2>/dev/null) ) ]]; then CXX=$(command -v CC); fi

MARCH_ERROR=$($CC $SH_MARCH -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$MARCH_ERROR" -ne "0" ]]; then
    SH_MARCH=
fi

SH_PIC="-fPIC"
PIC_ERROR=$($CC $SH_PIC -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$PIC_ERROR" -ne "0" ]]; then
    SH_PIC=
fi

# For the benefit of OpenSSL. Make it run fast.
SH_NATIVE="-march=native"
NATIVE_ERROR=$($CC $SH_NATIVE -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$NATIVE_ERROR" -ne "0" ]]; then
    SH_NATIVE=
fi

SH_DTAGS="-Wl,--enable-new-dtags"
DT_ERROR=$($CC $SH_DTAGS -x c -c -o /dev/null - </dev/null 2>&1 | grep -i -c error)
if [[ "$DT_ERROR" -ne "0" ]]; then
    SH_DTAGS=
fi

###############################################################################

# If IS_EXPORTED=1, then it was set in the parent shell
IS_EXPORTED=$(export | grep -c SUDO_PASSWWORD)
if [[ "$IS_EXPORTED" -eq "0" ]]; then

  echo
  echo "If you enter a sudo password, then it will be used for installation."
  echo "If you don't enter a password, then ensure INSTALL_PREFIX is writable."
  echo "To avoid sudo and the password, just press ENTER and they won't be used."
  read -r -s -p "Please enter password for sudo: " SUDO_PASSWWORD
  echo

  # If IS_EXPORTED=2, then we unset it after we are done
  export SUDO_PASSWWORD
  IS_EXPORTED=2
fi

###############################################################################

echo
echo "********** Bzip **********"
echo

wget "http://www.bzip.org/1.0.6/$BZIP2_TAR" -O "$BZIP2_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$BZIP2_DIR" &>/dev/null
gzip -d < "$BZIP2_TAR" | tar xf -
cd "$BZIP2_DIR"

# Fix Bzip install paths
cp Makefile Makefile.orig
sed 's|$(PREFIX)/lib|$(LIBDIR)|g' Makefile.orig > Makefile
rm Makefile.orig
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed 's|$(PREFIX)/lib|$(LIBDIR)|g' Makefile-libbz2_so.orig > Makefile-libbz2_so
rm Makefile-libbz2_so.orig

# Fix Bzip cpu architecture
cp Makefile Makefile.orig
sed "s|CFLAGS=|CFLAGS=$SH_MARCH |g" Makefile.orig > Makefile
cp Makefile Makefile.orig
sed "s|CXXFLAGS=|CXXFLAGS=$SH_MARCH |g" Makefile.orig > Makefile
rm Makefile.orig
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|CFLAGS=|CFLAGS=$SH_MARCH |g" Makefile-libbz2_so.orig > Makefile-libbz2_so
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|CXXFLAGS=|CXXFLAGS=$SH_MARCH |g" Makefile-libbz2_so.orig > Makefile-libbz2_so
rm Makefile-libbz2_so.orig

# Fix Bzip missing PIC
cp Makefile Makefile.orig
sed "s|CFLAGS=|CFLAGS=$SH_PIC |g" Makefile.orig > Makefile
cp Makefile Makefile.orig
sed "s|CXXFLAGS=|CXXFLAGS=$SH_PIC |g" Makefile.orig > Makefile
rm Makefile.orig
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|CFLAGS=|CFLAGS=$SH_PIC |g" Makefile-libbz2_so.orig > Makefile-libbz2_so
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|CXXFLAGS=|CXXFLAGS=$SH_PIC |g" Makefile-libbz2_so.orig > Makefile-libbz2_so
rm Makefile-libbz2_so.orig

# Add RPATH
cp Makefile Makefile.orig
sed "s|LDFLAGS=|LDFLAGS=$SH_MARCH -Wl,-rpath,$INSTALL_LIBDIR -L$INSTALL_LIBDIR|g" Makefile.orig > Makefile
rm Makefile.orig
cp Makefile-libbz2_so Makefile-libbz2_so.orig
sed "s|LDFLAGS=|LDFLAGS=$SH_MARCH -Wl,-rpath,$INSTALL_LIBDIR -L$INSTALL_LIBDIR|g" Makefile-libbz2_so.orig > Makefile-libbz2_so
rm Makefile-libbz2_so.orig

MAKE_FLAGS=("-j" "$MAKE_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=(install "PREFIX=$INSTALL_PREFIX" "LIBDIR=$INSTALL_LIBDIR")
if [[ ! (-z "$SUDO_PASSWWORD") ]]; then
    echo "$SUDO_PASSWWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$BZIP2_TAR" "$BZIP2_DIR")

    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openssl.sh 2>&1 | tee build-openssl.log
    if [[ -e build-openssl.log ]]; then
        rm build-openssl.log
    fi
fi

# If IS_EXPORTED=2, then we set it
if [[ "$IS_EXPORTED" -eq "2" ]]; then
    unset SUDO_PASSWORD
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
