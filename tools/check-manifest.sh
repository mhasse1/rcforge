#!/usr/bin/env bash
# check-manifest.sh - Extremely simple manifest verification
# Author: rcForge Team (modified by AI)
# Date: 2025-04-08
# Version: 0.8
# Category: tools/developer
# Description:
#    - Reads through the file system looking for files not in the file-manifest. Also
#      compares files to an ignore list. If they are in the manifest or ignore file,
#      it move to the next file. If not, prompts user to add to manifest, ignore file
#      or temporarily skip (default). Takes indicated action.
#
#    - Reverses compare to make sure everything in the manifest is in the file system
#      and provides a list of files that are not found in the file system.
#
#    THIS IS A HACK.



readonly project_dir="${HOME}/src/rcforge"
readonly manifest_file="${project_dir}/file-manifest.txt"
readonly ignore_file="${project_dir}/tools/.manifest_ignore"

readonly manifest=`grep -A5000 -m1 -e 'FILES:' ${manifest_file} | grep -iv "^#" | grep -iv "FILES:" | cut -d' ' -f1`
readonly ignore=`cat ${ignore_file}`
readonly filelist=`find . -type f | grep -iv "^\.\/\." | sort`

manifest_added=0
ignore_added=0
skipped=0
not_found_count=0

for fullname in `find . -type f | grep -iv "^\.\/\." | sort`; do
  fname=${fullname:2}

  echo "$manifest" | grep -q "$fname" && continue
  # [[ $? -eq 1 ]] && continue

	echo "$ignore" | grep -q "$fname" && continue
  # [[ $? -eq 0 ]] && continue

	read -n 1 -p "[FILE NAME MISSING] ${fname} (m)anifest (i)gnore (s)kip?" ans
	case "$ans" in
		"m")
			echo " add to manifest"
			printf "# %-47s %s\n" $fname $fname >> $manifest_file
			(( manifest_added++ ))
			;;
		"i")
			echo " add to ignore"
			printf "%s\n"         $fname        >> $ignore_file
			(( ignore_added++ ))
			;;
		*)
			echo " skip"
			(( skipped++ ))
			;;
	esac
done
echo

for fname in `grep -A5000 -m1 -e 'FILES:' ${manifest_file} | grep -iv "^#" | grep -iv "FILES:" | cut -d' ' -f1`; do
	echo "$filelist" | grep -q "$fname"
  if [[ $? -eq 1 ]]; then
  	echo "[FILE NOT FOUND] ${fname} in manifest, not found at specified location."
		(( not_found_count++ ))
	fi
done
echo

echo "${manifest_added} added to ${manifest_file}"
echo "${ignore_added} added to ${ignore_file}"
echo "${skipped} skipped"
echo "${not_found_count} files not found in filesystem"
