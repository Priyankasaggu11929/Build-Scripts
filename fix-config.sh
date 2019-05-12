#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script fixes configure and configure.ac

###############################################################################

CURR_DIR=$(pwd)
function finish {
  cd "$CURR_DIR"
}
trap finish EXIT

###############################################################################

# Autoconf lib paths are wrong for Fedora and Solaris. Thanks NM.
# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec;

echo "patching sys_lib_dlsearch_path_spec..."

for file in $(find "$PWD" -iname 'configure')
do
    sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' "$file" > "$file.fixed"
    chmod +w "$file" && mv "$file.fixed" "$file"
    chmod +x "$file"
done

for file in $(find "$PWD" -iname 'configure.ac')
do
    sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' "$file" > "$file.fixed"
    chmod +w "$file" && mv "$file.fixed" "$file"
    touch -t 197001010000 "$file"
done

echo "patching config.sub..."

find "$PWD" -name config.sub -exec bash -c 'cp ../patch/config.sub "$1"' _ {} \;

echo "patching config.guess..."

find "$PWD" -name config.guess -exec bash -c 'cp ../patch/config.guess "$1"' _ {} \;
echo ""
