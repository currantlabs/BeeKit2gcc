#!/usr/bin/env sh

dir=$1
file=$2
echo -n "Generating make instructions for ${dir}..."
echo "SRCDIR_$dir := \\" > $file

find $dir -name *.c | sed 's|/[^/]*$| \\|' | sort -u >> $file

echo " " >> $file
echo "OBJ_$dir := \$(foreach dir,\$(SRCDIR_$dir), \\" >> $file
echo "        \$(patsubst %.c,%.o, \\" >> $file
echo "	      \$(wildcard \$(dir)/*.c)))" >> $file

echo " Done."
