#!/usr/bin/env bash
# install-script.sh - rcForge Installation Script
# Author: rcForge Team
# Date: 2023-01-10
# Version: 0.5.0
# Description: Installs or upgrades rcForge, handling XDG migration if needed.
#              Requires Bash 4.3+ and curl.

# Set strict mode
set -o nounset
set -o errexit
set -o pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Core paths (XDG structure)
RELEASE_TAG=""
GITHUB_REPO="mhasse1/rcforge"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/rcforge"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rcforge"
OLD_RCFORGE_DIR="$HOME/.config/rcforge" # Pre-0.5.0 path
BACKUP_DIR="${DATA_HOME}/backups"
RUNTIME=$(date +%Y%m%d%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/rcforge_backup_$RUNTIME.tar.gz"
MANIFEST_TEMP="/tmp/rcforge_manifest_$"
GITHUB_BASE_URL=""

# Minimum Bash version required
REQUIRED_BASH_VERSION="4.3"

# ============================================================================
# UTILITY FUNCTIONS AND VARIBLES
# ============================================================================

# Simple command existence check
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

##### UTILITY VARIABLES
# Create spaces variable to clear printf "\r" lines
spaces=$(printf "%30s" "")
# If fold exists, use it, otherwise use cat
$(command_exists fold) && FOLD="$(which fold) -s" || FOLD=$(which cat)
##### END UTILITY VARIABLES

# simple associative array dump for debugging
_debug_print_hash() {
	declare -n hash_ref="$1"

	printf '%.s-' $(seq -s " " 75)
	printf "\n*** Markdown table. Paste as plain text.*** \n\n"
	echo "| KEY | VALUE |"
	echo "|-----|-------|"

	for key in "${!hash_ref[@]}"; do
		printf "| %q | %q |\n" "$key" "${hash_ref[$key]}"
	done

	printf '%.s-' $(seq -s " " 75)
	echo ""
}

# Simple error handler that exits with a message
error_exit() {
	echo "ERROR: $1" >&2
	# Clean up temp files
	rm -f "$MANIFEST_TEMP" &>/dev/null || true
	exit 1
}

# Check if Bash version meets requirements
check_bash_version() {
	printf "Checking Bash version...\r"
	if [[ -z "${BASH_VERSION:-}" ]]; then
		error_exit "This installer requires Bash ${REQUIRED_BASH_VERSION}+ to run."
	fi

	# Use printf and sort for reliable version comparison
	if ! printf '%s\n%s\n' "$REQUIRED_BASH_VERSION" "$BASH_VERSION" | sort -V -C &>/dev/null; then
		error_exit "Bash version (${BASH_VERSION}) is too old. Required: v${REQUIRED_BASH_VERSION}+."
	fi

	echo "✓ Bash version ${BASH_VERSION} found"
}

# Download a file with curl
download_file() {
	local url="$1"
	local destination="$2"

	# Create directory if it doesn't exist
	mkdir -p "$(dirname "$destination")"

	printf "Downloading: %-30s\r" "$(basename "$destination")"

	# Download with curl
	if ! curl --fail --silent --show-error --location --output "$destination" "$url"; then
		error_exit "Failed to download: $url"
	fi

	# Set permissions based on file type
	if [[ "$destination" == *.sh ]]; then
		chmod 700 "$destination"
	else
		chmod 600 "$destination"
	fi
}

# Check if rcForge is installed
is_installed() {
	# Check both old and new locations
	[[ -f "${DATA_HOME}/rcforge.sh" ]] || [[ -f "${OLD_RCFORGE_DIR}/rcforge.sh" ]]
}

# Check if XDG migration is needed
needs_xdg_migration() {
	# Only need migration if old structure exists but new one doesn't
	[[ -f "${OLD_RCFORGE_DIR}/rcforge.sh" ]] && [[ ! -f "${DATA_HOME}/rcforge.sh" ]]
}

# Create backup of existing installation
create_backup() {
	printf "Creating backup of existing installation...\r"

	# Ensure backup directory exists
	mkdir -p "$BACKUP_DIR"
	chmod 700 "$BACKUP_DIR"

	# Determine what to back up based on installation state
	if [[ -d "$DATA_HOME" ]] && [[ -d "$CONFIG_HOME" ]]; then
		# Backup XDG structure (both directories)
		tar -czf "$BACKUP_FILE" -C "$(dirname "$CONFIG_HOME")" "$(basename "$CONFIG_HOME")" \
			-C "$(dirname "$DATA_HOME")" "$(basename "$DATA_HOME")"
	elif [[ -d "$OLD_RCFORGE_DIR" ]]; then
		# Backup old legacy structure
		tar -czf "$BACKUP_FILE" -C "$(dirname "$OLD_RCFORGE_DIR")" "$(basename "$OLD_RCFORGE_DIR")"
	else
		unset BACKUP_FILE
		return 0
	fi

	if [[ -v BACKUP_FILE ]]; then
		if [[ -r $BACKUP_FILE ]]; then
			chmod 600 "$BACKUP_FILE"
			echo "✓ Backup created: $BACKUP_FILE"
		else
			error_exit "Unknown backup error. Please correct and retry."
		fi
	else
		echo "✓ Backup not required${spaces}"
	fi
	echo ""
}

# Perform XDG migration
migrate_to_xdg() {
	echo "Migrating to XDG directory structure..."

	# Check if old and new config paths are the same
	if [[ "$OLD_RCFORGE_DIR" == "$CONFIG_HOME" ]]; then
		printf "Renaming existing directory to avoid conflicts...\r"
		local backup_dir="${CONFIG_HOME}.${RUNTIME}"

		# Rename the old directory
		if ! mv -i "$OLD_RCFORGE_DIR" "$backup_dir"; then
			error_exit "Failed to rename existing directory for migration."
		fi

		# Update the old directory reference
		OLD_RCFORGE_DIR="$backup_dir"
		echo "✓ Renamed old config directory to ${backup_dir}"
	fi

	# Create base directories
	mkdir -p "$CONFIG_HOME" "$DATA_HOME"
	chmod 700 "$CONFIG_HOME" "$DATA_HOME"

	# Migrate user configuration scripts
	if [[ -d "${OLD_RCFORGE_DIR}/rc-scripts" ]]; then
		mkdir -p "${CONFIG_HOME}/rc-scripts"
		chmod 700 "${CONFIG_HOME}/rc-scripts"
		cp -p "${OLD_RCFORGE_DIR}/rc-scripts/"* "${CONFIG_HOME}/rc-scripts/" 2>/dev/null || true
		echo "✓ Migrated RC scripts to ${CONFIG_HOME}/rc-scripts/"
	fi

	# Migrate user utilities
	if [[ -d "${OLD_RCFORGE_DIR}/utils" ]]; then
		mkdir -p "${CONFIG_HOME}/utils"
		chmod 700 "${CONFIG_HOME}/utils"
		cp -p "${OLD_RCFORGE_DIR}/utils/"* "${CONFIG_HOME}/utils/" 2>/dev/null || true
		echo "✓ Migrated utilities to ${CONFIG_HOME}/utils/"
	fi

	# Migrate checksums (if they exist)
	if [[ -d "${OLD_RCFORGE_DIR}/docs/checksums" ]]; then
		mkdir -p "${DATA_HOME}/config/checksums"
		chmod 700 "${DATA_HOME}/config/checksums"
		cp -p "${OLD_RCFORGE_DIR}/docs/checksums/"* "${DATA_HOME}/config/checksums/" 2>/dev/null || true
		echo "✓ Migrated checksums to ${DATA_HOME}/config/checksums/"
	fi

	# Migrate Bash location file if it exists
	if [[ -f "${OLD_RCFORGE_DIR}/docs/.bash_location" ]]; then
		mkdir -p "${DATA_HOME}/config"
		chmod 700 "${DATA_HOME}/config"
		cp -p "${OLD_RCFORGE_DIR}/docs/.bash_location" "${DATA_HOME}/config/bash-location"
		echo "✓ Migrated rcForge script-execution config"
	fi

	echo "✓ Migration complete."
	echo ""
	printf "The old directory at '${OLD_RCFORGE_DIR}' is no longer needed. Review its contents and remove manually.\n" | $FOLD
	echo ""
}

# Verify, prepare and extract manifest
preprocess_manifest() {
	printf "Processing manifest file...\r"

	# Create a temporary file for the processed manifest
	local processed_manifest="/tmp/rcforge_processed_manifest_$$"

	# Validate manifest structure first
	if ! grep -q "^DIRECTORIES:" "$MANIFEST_TEMP"; then
		error_exit "Invalid manifest format: Missing required DIRECTORIES section"
	fi

	if ! grep -q "^FILES:" "$MANIFEST_TEMP"; then
		error_exit "Invalid manifest format: Missing required FILES section"
	fi

	# Process the manifest file:
	# 1. Replace XDG placeholders
	# 2. Remove comments and blank lines
	# 3. Maintain section headers
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

	# Verify the processed file has content
	if [[ ! -s "$processed_manifest" ]]; then
		error_exit "Error processing manifest: Empty result"
	fi

	# Replace the original temp manifest with the processed one
	mv "$processed_manifest" "$MANIFEST_TEMP"

	# Initialize global arrays for directories and files
	declare -ga MANIFEST_DIRS=()  # For explicitly listed directories (empty ones)
	declare -gA MANIFEST_FILES=() # For file mappings
	declare -gA ALL_DIRS=()       # For tracking all directories (including file parents)

	# Extract directories and files into arrays
	local current_section=""
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
				local dest_dir=$(dirname "$dest_path")
				ALL_DIRS["$dest_dir"]=1
			else
				error_exit "Invalid file mapping in manifest: '$line' - Both source and destination must be specified"
			fi
		fi
	done <"$MANIFEST_TEMP"

	# Validate extraction results
	if [[ ${#MANIFEST_FILES[@]} -eq 0 ]]; then
		error_exit "No file mappings found in manifest"
	fi

	echo "✓ Manifest processed: ${#ALL_DIRS[@]} directories (${#MANIFEST_DIRS[@]} explicit) and ${#MANIFEST_FILES[@]} file mappings found"

	return 0
}

# Install files from manifest
process_manifest() {
	echo "Installing rcForge files from manifest..."

	local dir_count=0 file_count=0 skip_count=0
	local dest_path="" source_path="" file_url=""

	# Create all required directories first
	printf "Creating directories...\r"
	for dir_path in "${!ALL_DIRS[@]}"; do
		if mkdir -p "$dir_path"; then
			chmod 700 "$dir_path"
			dir_count=$((dir_count + 1))
		else
			error_exit "Failed to create directory: $dir_path"
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
		file_url="${GITHUB_BASE_URL}/${source_path}"
		download_file "$file_url" "$dest_path" || error_exit "Failed to download/install $source_path to $dest_path"
		file_count=$((file_count + 1))
	done
	printf "✓ File download complete${spaces}\n"

	echo "✓ Created $dir_count directories"
	echo "✓ Downloaded $file_count files"

	if [[ $skip_count -gt 0 ]]; then
		echo "  Skipped $skip_count existing user configuration files"
	fi

	# Special case for API keys file
	api_keys_file="${DATA_HOME}/config/api-keys.conf"
	if [[ -f "$api_keys_file" ]]; then
		chmod 600 "$api_keys_file"
	fi

	# Save the installed version to a file
	local version_file="${DATA_HOME}/config/rcforge-version.conf"
	mkdir -p "$(dirname "$version_file")"
	echo "RCFORGE_VERSION=\"$RELEASE_TAG\"" >"$version_file"
	chmod 600 "$version_file"
	echo "✓ Configuration of version $RELEASE_TAG complete"

	return 0
}

# Update shell RC files if needed
update_rc_files() {
	printf "Checking shell RC files...\r"

	local rc_files=("$HOME/.bashrc" "$HOME/.zshrc")
	local source_line="source \"\${XDG_DATA_HOME:-\$HOME/.local/share}/rcforge/rcforge.sh\""

	for rc_file in "${rc_files[@]}"; do
		if [[ ! -f "$rc_file" ]]; then
			continue
		fi

		# Check if rcforge is already sourced
		if grep -q "rcforge/rcforge.sh" "$rc_file"; then
			echo "✓ rcForge sourced in $rc_file; no changes applied"
		else
			# Add source line
			echo "" >>"$rc_file"
			echo "# rcForge - Shell Configuration Manager (Added $(date +%Y-%m-%d))" >>"$rc_file"
			echo "$source_line" >>"$rc_file"
			echo "✓ Added rcForge source line to $rc_file"
		fi
	done
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

parse_arguments() {
	# Parse command line arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--release-tag=*)
				RELEASE_TAG="${1#*=}"
				shift
				;;
			--release-tag)
				if [[ -z "${2:-}" || "$2" == -* ]]; then
					error_exit "--release-tag requires a value."
				fi
				RELEASE_TAG="$2"
				shift 2
				;;
			--manifest)
				if [[ -z "${2:-}" || "$2" == -* ]]; then
					error_exit "--manifest requires a value."
				fi
				MANIFEST="$2"
				if [[ ! -r $MANIFEST ]]; then
					error_exit "$MANIFEST not found or cannot be read."
				fi
				shift 2
				;;
			--help)
				echo "rcForge Installer"
				echo ""
				echo "Usage: $(basename "$0") [--release-tag=TAG]"
				echo ""
				echo "Options:"
				echo "  --release-tag=TAG   Specify GitHub release tag (e.g., v0.5.0)"
				echo "                      Optional: Will use latest release if not specified"
				echo "  --manifest=manifest Specify a local file-manifest (e.g. fm.txt)"
				echo "                      Optional: Will use release manifest if not specified"
				echo "  --help              Show this help message"
				exit 0
				;;
			*)
				error_exit "Unknown option: $1"
				;;
		esac
	done

	# If no release tag provided, get the latest release
	if [[ -z "$RELEASE_TAG" ]]; then
		echo "No release tag specified. Getting latest release from GitHub..."

		# Query GitHub API for the latest release
		if ! command_exists curl; then
			error_exit "curl is required for installation but not found. Please install curl and try again."
		fi

		LATEST_RELEASE=$(curl --silent "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")

		# Check if API call was successful and has tag_name
		if [[ "$LATEST_RELEASE" == *"tag_name"* ]]; then
			RELEASE_TAG=$(echo "$LATEST_RELEASE" | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
			echo "Latest release tag: $RELEASE_TAG"
		else
			error_exit "Could not determine latest release. Please specify a release tag with --release-tag or report this issue at: https://github.com/${GITHUB_REPO}/issues"
		fi
	fi

	# Set GitHub URL based on release tag
	GITHUB_BASE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${RELEASE_TAG}"
}

# ============================================================================
# MAIN INSTALLATION FUNCTION
# ============================================================================

main() {
	echo ""
	echo "rcForge Installer - Installing from tag: $RELEASE_TAG"
	echo "GitHub URL: $GITHUB_BASE_URL"

	# 1. Check requirements
	check_bash_version

	if ! command_exists curl; then
		error_exit "curl is required for installation but not found. Please install curl and try again."
	fi

	# 2. Download and process the manifest file (or use provided file)
	printf "Downloading manifest...\r"
	if [[ -v MANIFEST && ! -z "$MANIFEST" ]]; then
		cp $MANIFEST $MANIFEST_TEMP
	else
		manifest_url="${GITHUB_BASE_URL}/file-manifest.txt"
		download_file "$manifest_url" "$MANIFEST_TEMP"
	fi
	printf "✓ Manifest download complete${spaces}\n"
	preprocess_manifest

	# 3. Create backup if necessary
	if is_installed; then
		create_backup

		# 4. Check if XDG migration is needed
		if needs_xdg_migration; then
			echo "Detected pre-XDG installation. $spaces"
			migrate_to_xdg
		else
			echo "Detected XDG-compliant installation. Updating."
		fi
	else
		echo "No existing installation detected. Installing."
	fi

	# 5. Create directories and install files
	process_manifest

	# 6. Update shell RC files if needed
	update_rc_files

	# 7. Clean up and show completion message
	rm -f "$MANIFEST_TEMP"

	echo "✓ rcForge installation complete!"
	echo ""
	echo "To activate rcForge in your CURRENT shell session, run:"
	echo "  source \"\${XDG_DATA_HOME:-\$HOME/.local/share}/rcforge/rcforge.sh\""
	echo ""
	echo "Verify this line is present in your shell rc files."
	echo ""
	echo "When rcForge starts, there is a 1-second window to press '.' to abort. This emergency escape feature can be helpful if your configuration is forcing a logout or there are other issues." | $FOLD
	echo ""

	return 0
}

# Run the installer
parse_arguments "$@"
main
