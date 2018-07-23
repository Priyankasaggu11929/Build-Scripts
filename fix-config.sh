#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script fixes configure and configure.ac

###############################################################################

for file in $(find "$PWD" -iname 'configure')
do
	# Autoconf lib paths are wrong for Fedora and Solaris. Thanks NM.
	# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec;
	sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' "$file" > "$file.fixed"
	# Can't use "sed -i" missing on BSDs, OS X and Solaris
	mv "$file.fixed" "$file"
	# AIX needs the execute bit reset on the file.
	chmod +x "$file"
done

for file in $(find "$PWD" -iname 'configure.ac')
do
	# Autoconf lib paths are wrong for Fedora and Solaris. Thanks NM.
	# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec;
	sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' "$file" > "$file.fixed"
	# Can't use "sed -i" missing on BSDs, OS X and Solaris
	mv "$file.fixed" "$file"
	# Keep the filetime old so Autoconf does not re-configure
	touch -t 197001010000 "$file"
done
