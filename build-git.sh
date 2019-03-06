
#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Git and its dependencies from sources.

GIT_TAR=git-2.21.0.tar.gz
GIT_DIR=git-2.21.0

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
if ! source ./build-environ.sh
then
    echo "Failed to set environment"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

COMODO_ROOT="$HOME/.cacert/comodo-rsa-root.pem"
if [[ ! -f "$COMODO_ROOT" ]]; then
    echo "Git requires several CA roots. Please run build-cacerts.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
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

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-iconv.sh
then
    echo "Failed to build iConv"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-pcre.sh
then
    echo "Failed to build PCRE and PCRE2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

if ! ./build-curl.sh
then
    echo "Failed to build cURL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

# Required
if ! perl -MExtUtils::MakeMaker -e1 2>/dev/null
then
    echo ""
    echo "Git requires Perl's ExtUtils::MakeMaker."
    echo "To fix this issue, please install ExtUtils-MakeMaker."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

echo
echo "********** Git **********"
echo

"$WGET" --ca-certificate="$CA_ZOO" "https://mirrors.edge.kernel.org/pub/software/scm/git/$GIT_TAR" -O "$GIT_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download Git. Attempting to skip validation checks."
	"$WGET" --no-check-certificate "https://mirrors.edge.kernel.org/pub/software/scm/git/$GIT_TAR" -O "$GIT_TAR"
	if [[ "$?" -ne "0" ]]; then
		echo "Failed to download Git."
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
fi

rm -rf "$GIT_DIR" &>/dev/null
gzip -d < "$GIT_TAR" | tar xf -
cd "$GIT_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

if ! "$MAKE" configure
then
    echo "Failed to make configure Git"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

for file in $(find "$PWD" -iname 'Makefile*')
do
    sed -e 's|-lrt|-lrt -lpthread|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    sed -e 's|rGIT-PERL-HEADER|r GIT-PERL-HEADER|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    touch -t 197001010000 "$file"
done

# Various Solaris 11 workarounds
if [[ "$IS_SOLARIS" -eq "1" ]]; then
    for file in $(find "$PWD" -iname 'Makefile*')
    do
        sed -e 's|-lsocket|-lnsl -lsocket|g' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"
        sed -e 's|/usr/ucb/install|install|g' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"
        touch -t 197001010000 "$file"
    done
    for file in $(find "$PWD" -name 'config*')
    do
        sed -e 's|-lsocket|-lnsl -lsocket|g' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"
        sed -e 's|/usr/ucb/install|install|g' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"
        chmod +x "$file"
        touch -t 197001010000 "$file"
    done
fi

if [[ -e /usr/local/bin/perl ]]; then
    SH_PERL=/usr/local/bin/perl
elif [[ -e /usr/bin/perl ]]; then
    SH_PERL=/usr/bin/perl
else
    SH_PERL=perl
fi

    PERL="$SH_PERL" \
    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="-lssl -lcrypto -lz ${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" \
    --with-lib=$(basename "$INSTX_LIBDIR") \
    --enable-pthreads --with-openssl="$INSTX_PREFIX" \
    --with-curl="$INSTX_PREFIX" --with-libpcre="$INSTX_PREFIX" \
    --with-zlib="$INSTX_PREFIX" --with-iconv="$INSTX_PREFIX" \
    --with-perl="$SH_PERL"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Git"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# See INSTALL for the formats and the requirements
MAKE_FLAGS=("-j" "$INSTX_JOBS")

if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Git"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# See INSTALL for the formats and the requirements
MAKE_FLAGS=("install")

# Git builds things during install, and they end up root:root.
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
    echo "$SUDO_PASSWORD" | sudo -S chmod -R 0777 ./*
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Configuring Git to use CA store at $SH_CACERT_PATH/cacert.pem"
echo "*****************************************************************************"

git config --global http.sslCAInfo "$SH_CACERT_FILE"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$GIT_TAR" "$GIT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-git.sh 2>&1 | tee build-git.log
    if [[ -e build-git.log ]]; then
        rm -f build-git.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
