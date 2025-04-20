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
BACKUP_FILE="${BACKUP_DIR}/rcforge_backup_$(date +%Y%m%d%H%M%S).tar.gz"
MANIFEST_TEMP="/tmp/rcforge_manifest_$"
GITHUB_BASE_URL=""

# Minimum Bash version required
REQUIRED_BASH_VERSION="4.3"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Simple error handler that exits with a message
error_exit() {
	echo "ERROR: $1" >&2
	# Clean up temp files
	rm -f "$MANIFEST_TEMP" &>/dev/null || true
	exit 1
}

# Simple command existence check
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Check if Bash version meets requirements
check_bash_version() {
	echo "Checking Bash version..."
	if [[ -z "${BASH_VERSION:-}" ]]; then
		error_exit "This installer requires Bash ${REQUIRED_BASH_VERSION}+ to run."
	fi

	# Use printf and sort for reliable version comparison
	if ! printf '%s\n%s\n' "$REQUIRED_BASH_VERSION" "$BASH_VERSION" | sort -V -C &>/dev/null; then
		error_exit "Bash version (${BASH_VERSION}) is too old. Required: v${REQUIRED_BASH_VERSION}+."
	fi

	echo "✓ Bash version ${BASH_VERSION} meets requirements."
}

# Download a file with curl
download_file() {
	local url="$1"
	local destination="$2"

	# Create directory if it doesn't exist
	mkdir -p "$(dirname "$destination")"

	echo "Downloading: $(basename "$destination")"

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
	echo "Creating backup of existing installation..."

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
		echo "No existing installation found to back up."
		return 0
	fi

	chmod 600 "$BACKUP_FILE"
	echo "✓ Backup created: $BACKUP_FILE"
}

# Perform XDG migration
migrate_to_xdg() {
	echo "Migrating to XDG directory structure..."

	# Check if old and new config paths are the same
	if [[ "$OLD_RCFORGE_DIR" == "$CONFIG_HOME" ]]; then
		echo "Renaming existing directory to avoid conflicts..."
		local backup_dir="${CONFIG_HOME}.pre-xdg"

		# Rename the old directory
		if ! mv "$OLD_RCFORGE_DIR" "$backup_dir"; then
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
		echo "✓ Migrated Bash location information."
	fi

	echo "✓ Migration complete."
	echo "NOTE: The old directory at '${OLD_RCFORGE_DIR}' is no longer needed."
	echo "      You may want to review its contents and remove it manually."
}

# Install files from manifest
process_manifest() {
	echo "Installing rcForge files from manifest..."

	local in_section="NONE"
	local line="" source_path="" dest_path=""
	local dir_count=0 file_count=0 skip_count=0

	# Process manifest line by line
	while IFS= read -r line; do
		# Skip comments and empty lines
		[[ -z "$line" || "$line" =~ ^# ]] && continue

		# Handle section markers
		if [[ "$line" == "DIRECTORIES:" ]]; then
			in_section="DIRS"
			continue
		elif [[ "$line" == "FILES:" ]]; then
			in_section="FILES"
			continue
		fi

		# Process directories
		if [[ "$in_section" == "DIRS" ]]; then
			# Replace XDG placeholders
			line="${line//\{xdg-home\}/${CONFIG_HOME}}"
			line="${line//\{xdg-data\}/${DATA_HOME}}"

			# Create directory and set permissions
			mkdir -p "$line"
			chmod 700 "$line"
			((dir_count++))

		# Process files
		elif [[ "$in_section" == "FILES" ]]; then
			# Split line into source and destination paths
			read -r source_path dest_path <<<"$line"

			# Skip if line format is invalid
			if [[ -z "$source_path" || -z "$dest_path" ]]; then
				continue
			fi

			# Replace XDG placeholders in destination path
			dest_path="${dest_path//\{xdg-home\}/${CONFIG_HOME}}"
			dest_path="${dest_path//\{xdg-data\}/${DATA_HOME}}"

			# Skip user configuration files that already exist
			if [[ "$dest_path" == ${CONFIG_HOME}/* ]] && [[ -f "$dest_path" ]]; then
				# Handle templates differently - check if the non-template file exists
				if [[ "$dest_path" == *.template ]]; then
					actual_file="${dest_path%.template}"
					if [[ -f "$actual_file" ]]; then
						((skip_count++))
						continue
					else
						# Template file but actual file doesn't exist - download and rename
						dest_path="$actual_file"
					fi
				else
					# Regular config file that already exists - skip
					((skip_count++))
					continue
				fi
			fi

			# Construct download URL and get the file
			file_url="${GITHUB_BASE_URL}/${source_path}"
			download_file "$file_url" "$dest_path"
			((file_count++))
		fi
	done <"$MANIFEST_TEMP"

	echo "✓ Created $dir_count directories."
	echo "✓ Downloaded $file_count files."

	if [[ $skip_count -gt 0 ]]; then
		echo "  Skipped $skip_count existing user configuration files."
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
	echo "✓ Saved installation version: $RELEASE_TAG"
}

# Update shell RC files if needed
update_rc_files() {
	echo "Checking shell RC files..."

	local rc_files=("$HOME/.bashrc" "$HOME/.zshrc")
	local source_line="source \"\${XDG_DATA_HOME:-\$HOME/.local/share}/rcforge/rcforge.sh\""

	for rc_file in "${rc_files[@]}"; do
		if [[ ! -f "$rc_file" ]]; then
			continue
		fi

		# Check if rcforge is already sourced
		if grep -q "rcforge/rcforge.sh" "$rc_file"; then
			echo "  rcForge already sourced in $rc_file - no changes made."
		else
			# Add source line
			echo "" >>"$rc_file"
			echo "# rcForge - Shell Configuration Manager (Added $(date +%Y-%m-%d))" >>"$rc_file"
			echo "$source_line" >>"$rc_file"
			echo "✓ Added rcForge source line to $rc_file."
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
			--help)
				echo "rcForge Installer"
				echo ""
				echo "Usage: $(basename "$0") [--release-tag=TAG]"
				echo ""
				echo "Options:"
				echo "  --release-tag=TAG  Specify GitHub release tag (e.g., v0.5.0)"
				echo "                     Optional: Will use latest release if not specified"
				echo "  --help             Show this help message"
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
	echo "rcForge Installer - Installing from tag: $RELEASE_TAG"
	echo "GitHub URL: $GITHUB_BASE_URL"

	# 1. Check requirements
	check_bash_version

	if ! command_exists curl; then
		error_exit "curl is required for installation but not found. Please install curl and try again."
	fi

	# 2. Download and process the manifest file
	echo "Downloading manifest..."
	manifest_url="${GITHUB_BASE_URL}/file-manifest.txt"
	download_file "$manifest_url" "$MANIFEST_TEMP"

	# 3. Create backup if necessary
	if is_installed; then
		create_backup

		# 4. Check if XDG migration is needed
		if needs_xdg_migration; then
			echo "Detected pre-0.5.0 installation that needs XDG migration."
			migrate_to_xdg
		else
			echo "Existing XDG-compliant installation detected. Proceeding with update."
		fi
	else
		echo "No existing installation detected. Performing fresh install."
	fi

	# 5. Create directories and install files
	process_manifest

	# 6. Update shell RC files if needed
	update_rc_files

	# 7. Clean up and show completion message
	rm -f "$MANIFEST_TEMP"

	echo ""
	echo "✓ rcForge installation complete!"
	echo ""
	echo "To activate rcForge in your CURRENT shell session, run:"
	echo "  source \"\${XDG_DATA_HOME:-\$HOME/.local/share}/rcforge/rcforge.sh\""
	echo ""
	echo "For automatic loading in new sessions, ensure this line is present"
	echo "in your ~/.bashrc or ~/.zshrc (the installer has attempted to add it)."
	echo ""
	echo "TIP: When rcForge starts, you'll have a 1-second window to press '.' to abort"
	echo "     the loading process if needed. This emergency exit can be helpful if you"
	echo "     experience any issues with your configuration."
	echo ""

	return 0
}

# Run the installer
parse_arguments "$@"
main
