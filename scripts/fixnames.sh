#!/usr/bin/env bash

function search_and_replace {
    local old_name=$1
    local new_name=$2
    local wdir=$3
    files=$(grep -rl '^[[:blank:]]*#include[[:blank:]]*[<"]'"$old_name" "$wdir" --include='*.[ch]')
    for f in $files; do
	echo "Modifying includes in $f..."
	# Replace included file with correct name
	sed -r -i.bak "s|(#include *[<\"])$old_name|\1$new_name|" "$f"
	if [[ ! -z "$VERBOSE" ]]; then
	    # Present user with diff of output and ask for confirmation
	    diff -u ${f}.bak $f | less -eFX
	    response="bogus"
	    until [[ "$response" =~ [yYnN] || -z "$response" ]]; do
		echo -n "Looks good? [Y/n]"
		read response
	    done
	    if [[ $response =~ [Nn] ]]; then
		echo "Uh-oh! Reverting..."
		mv -f ${f}.bak $f
	    else
		echo "Good! Removing backup..."
	    fi
	fi
	# Otherwise just delete the file
	rm -f "${f}.bak"
    done
}

function header_rename() {
    old_name=$1
    new_name=$2
    wdir=$3
    echo "Renaming $old_name to $new_name..."
    svn info "$wdir" &>/dev/null && svn="svn"
    $svn mv "$wdir/$old_name" "$wdir/${old_name%/*}/$new_name"
}

function fixnames() {
    wdir=$(pwd)
    # This command selects all the included header names (the ones in #include directives)
    names=$(grep '^[[:blank:]]*#include [<"]' -r "$wdir" --include='*.[ch]' | sed 's|^.*["<]\([[:alnum:]_.-]\+\.h\)[">].*$|\1|' | sort -u)

    for name in $names; do
	real_path=$(find -iname "$name")
	real_name=${real_path##*/}
	[[ -z ${real_path} ]] && echo "No header file found for $name" && continue
	# If case is equal, carry on
	[[ "$name" == "$real_name" ]] && continue

	# If we get here, it means that there is a case mismatch.
	response=-1
	until [[ $response -lt 4 && $response -gt 0 ]]; do
	    echo "====================================================================="
	    echo "Case mismatch: file includes $name but header file is called $real_name"
	    echo -e "1) Use $name \t\t 2) Use $real_name \t\t 3) Specify new name by hand"
	    echo -n "What do you want to do? [1-3]: "
	    read response
	done
	case $response in
	    1)
	    	header_rename "$real_path" "$name" "$wdir"
		;;
	    2)
	    	search_and_replace "$name" "$real_name" "$wdir"
		;;
	    3)
		user_name=""
		while [[ -z "$user_name" ]]; do
		    echo -n "Input new filename: "
		    read user_name
		done
		header_rename "$real_path" "$user_name" "$wdir"
		search_and_replace "$name" "$user_name" "$wdir"
		;;
	    *)
		echo "Error"
		;;
	esac
    done
}

fixnames $@
