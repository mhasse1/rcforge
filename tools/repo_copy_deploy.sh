#!/usr/bin/env bash

root="${HOME}/src/rcforge"
temp="/tmp"
man="file-manifest.txt"
MANIFEST_TEMP=$temp/$man
processed_manifest=$MANIFEST_TEMP.temp

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/rcforge"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rcforge"

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

declare -ga MANIFEST_DIRS=()  # For explicitly listed directories (empty ones)
declare -gA MANIFEST_FILES=() # For file mappings
declare -gA ALL_DIRS=()       # For tracking all directories (including file parents)

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

dir_count=0
file_count=0
skip_count=0
dest_path=""
source_path=""
file_url=""

# Create all required directories first
printf "Creating directories...\r"
for dir_path in "${!ALL_DIRS[@]}"; do
	if mkdir -p "$dir_path"; then
		chmod 700 "$dir_path"
		dir_count=$((dir_count + 1))
	else
		echo "Failed to create directory: $dir_path"
		exit 1
	fi
done

# Process files
printf "Processing files...    \r"
for source_path in "${!MANIFEST_FILES[@]}"; do
	dest_path="${MANIFEST_FILES[$source_path]}"

	# Skip user configuration files that already exist
	if [[ "$dest_path" == ${CONFIG_HOME}/* ]] && [[ -f "$dest_path" ]]; then
		# Handle templates differently - check if the non-template file exists
		if [[ "$dest_path" == *.template ]]; then
			actual_file="${dest_path%.template}"
			if [[ -f "$actual_file" ]]; then
				skip_count=$((skip_count + 1))
				continue
			else
				# Template file but actual file doesn't exist - download and rename
				dest_path="$actual_file"
			fi
		else
			# Regular config file that already exists - skip
			skip_count=$((skip_count + 1))
			continue
		fi
	fi

	# Construct download URL and get the file
	file_url="$root/${source_path}"
	cp "$file_url" "$dest_path" || error_exit "Failed to copy $source_path to $dest_path"
	# echo cp "$file_url" " -> " "$dest_path"
	file_count=$((file_count + 1))
done

echo "✓ Created $dir_count directories"
echo "✓ Downloaded $file_count files"

if [[ $skip_count -gt 0 ]]; then
	echo "  Skipped $skip_count existing user configuration files"
fi
