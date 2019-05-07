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

echo "patching sys_lib_dlsearch_path_spec..."

for file in $(find "$PWD" -iname 'configure')
do
    # Autoconf lib paths are wrong for Fedora and Solaris. Thanks NM.
    # http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec;
    sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' "$file" > "$file.fixed"
    # Can't use "sed -i" missing on BSDs, OS X and Solaris
    chmod +w "$file" && mv "$file.fixed" "$file"
    # AIX needs the execute bit reset on the file.
    chmod +x "$file"
done

for file in $(find "$PWD" -iname 'configure.ac')
do
    # Autoconf lib paths are wrong for Fedora and Solaris. Thanks NM.
    # http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec;
    sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' "$file" > "$file.fixed"
    # Can't use "sed -i" missing on BSDs, OS X and Solaris
    chmod +w "$file" && mv "$file.fixed" "$file"
    # Keep the filetime old so Autoconf does not re-configure
    touch -t 197001010000 "$file"
done

if [[ -e build/config.guess ]]
then
    echo "patching config.guess..."
    cp -p ../patch/config.guess build/
fi

if [[ -e build/config.sub ]]
then
    echo "patching config.sub..."
    cp -p ../patch/config.sub build/
fi

if [[ -e build-aux/config.guess ]]
then
    echo "patching config.guess..."
    cp -p ../patch/config.guess build-aux/
fi

if [[ -e build-aux/config.sub ]]
then
    echo "patching config.sub..."
    cp -p ../patch/config.sub build-aux/
fi

if [[ -e config/config.guess ]]
then
    echo "patching config.guess..."
    cp -p ../patch/config.guess config/
fi

if [[ -e config/config.sub ]]
then
    echo "patching config.sub..."
    cp -p ../patch/config.sub config/
fi

if [[ -e support/config.guess ]]
then
    echo "patching config.guess..."
    cp -p ../patch/config.guess support/
fi

if [[ -e support/config.sub ]]
then
    echo "patching config.sub..."
    cp -p ../patch/config.sub support/
fi

if [[ -e config.guess ]]
then
    echo "patching config.guess..."
    cp -p ../patch/config.guess .
fi

if [[ -e config.sub ]]
then
    echo "patching config.sub..."
    cp -p ../patch/config.sub .
fi

echo ""
