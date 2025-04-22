#!/usr/bin/env bash

if [[ "$1" == "" ]]; then
	echo "Forgot hostname (bet this isn't the first time)"
	exit 1
fi

echo "Assuming destination will use defaults for XDG folders."

host=$1
root="${HOME}/src/rcforge"
temp="/tmp"
man="file-manifest.txt"
temp_dest="${temp}/rcforge-temp-install"
MANIFEST_TEMP=$temp/$man
processed_manifest=$MANIFEST_TEMP.temp

CONFIG_HOME="$temp_dest/.config/rcforge"
DATA_HOME="$temp_dest/.local/share/rcforge"

echo "git pull so we are up to date"
cd $root
git pull

echo "create the temp manifest and prepare for reading"
cp $root/$man $temp/
awk '
	# Skip comment lines and empty lines
	/^#/ || /^[[:space:]]*$/ { next }

	# Keep section headers as is
	/^DIRECTORIES:/ || /^FILES:/ { print; next }

	# Process and print all other lines
	{
	    # Replace placeholders
	    gsub(/\{xdg-home\}/, "'"$CONFIG_HOME"'")
	    gsub(/\{xdg-data\}/, "'"$DATA_HOME"'")
	    print
	}
 ' "$MANIFEST_TEMP" >"$processed_manifest"
mv "$processed_manifest" "$MANIFEST_TEMP"

echo "Declaring arrays"
declare -ga MANIFEST_DIRS=()  # For explicitly listed directories (empty ones)
declare -gA MANIFEST_FILES=() # For file mappings
declare -gA ALL_DIRS=()       # For tracking all directories (including file parents)

echo "Extracting manifest information"
# Extract directories and files into arrays
current_section=""
while IFS= read -r line; do
	# Track current section
	if [[ "$line" == "DIRECTORIES:" ]]; then
		current_section="dirs"
		continue
	elif [[ "$line" == "FILES:" ]]; then
		current_section="files"
		continue
	fi

	# Process based on current section
	if [[ "$current_section" == "dirs" ]]; then
		# Add explicitly listed directory to array
		MANIFEST_DIRS+=("$line")
		# Also track in all directories
		ALL_DIRS["$line"]=1
	elif [[ "$current_section" == "files" ]]; then
		# Split line into source and destination
		read -r source_path dest_path <<<"$line"
		if [[ -n "$source_path" && -n "$dest_path" ]]; then
			# Add to associative array
			MANIFEST_FILES["$source_path"]="$dest_path"

			# Track the parent directory of this file
			dest_dir=$(dirname "$dest_path")
			ALL_DIRS["$dest_dir"]=1
		else
			echo "Invalid file mapping in manifest: '$line' - Both source and destination must be specified"
			exit 1
		fi
	fi
done <"$MANIFEST_TEMP"

dest_path=""
source_path=""
file_url=""

echo "Creating directories"
# Create all required directories first
printf "Creating directories...\r"
for dir_path in "${!ALL_DIRS[@]}"; do
	if mkdir -p "$dir_path"; then
		chmod 700 "$dir_path"
	else
		echo "Failed to create directory: $dir_path"
		exit 1
	fi
done

echo "Copying files"
# Process files
for source_path in "${!MANIFEST_FILES[@]}"; do
	dest_path="${MANIFEST_FILES[$source_path]}"

	# Skip user configuration files
	if [[ "$dest_path" == ${CONFIG_HOME}/* ]]; then
		continue
	fi

	# Construct download URL and get the file
	file_url="$root/${source_path}"
	cp "$file_url" "$dest_path" || error_exit "Failed to copy $source_path to $dest_path"
	# echo cp "$file_url" " -> " "$dest_path"
done

echo ""
echo "Copying files to $host"
cd $temp_dest
scp -r ${temp_dest}/.local $host:~/

echo ""
echo "Cleanup"
cd /$temp
rm -rf $temp_desk $MANIFEST_TEMP
