#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script fixes LD_LIBRARY_PATH => DYLD_LIBRARY_PATH on OS X

if [[ "$IS_DARWIN" -ne 0 ]]
then
    grep -rl LD_LIBRARY_PATH "$PWD" | cut -f 1 -d ':' | sort | uniq | while IFS='' read -r file
    do
        echo "Patching $file..."
        sed 's/LD_LIBRARY_PATH/DYLD_LIBRARY_PATH/g' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"
    done
fi
