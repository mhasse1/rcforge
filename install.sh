#!/usr/bin/env bash
# install.sh - rcForge Stub Installer - Fetches and runs the installer from a specific tag or the latest release.
# Author: rcForge Team
# Date: 2025-04-15 # Updated Date
# Version: 0.4.3 # Stub Version (Incremented for new feature)
# Category: installer
# Description: Downloads the full installer ('install-script.sh') from a specific
#              GitHub release tag (if provided via --tag) or defaults to the latest
#              release. Executes the installer, passing the tag along.

# Set strict error handling
set -o nounset
set -o errexit
set -o pipefail

# --- Configuration ---
readonly OWNER_REPO="mhasse1/rcforge"
readonly FULL_INSTALLER_NAME="install-script.sh"
readonly TMP_INSTALLER="/tmp/rcforge_full_installer_$$"

# Colors (minimal, self-contained)
if [[ -t 1 ]]; then # Check if stdout is a tty
	readonly BLUE='\033[0;34m'
	readonly YELLOW='\033[0;33m'
	readonly RED='\033[0;31m'
	readonly RESET='\033[0m'
else
	readonly BLUE=""
	readonly YELLOW=""
	readonly RED=""
	readonly RESET=""
fi

# --- Utility Functions (Minimal) ---
InfoMessage() { printf "%bINFO:%b %s\n" "${BLUE}" "${RESET}" "${*}"; }
WarningMessage() { printf "%bWARNING:%b %s\n" "${YELLOW}" "${RESET}" "${*}" >&2; }
ErrorMessage() {
	printf "%bERROR:%b %s\n" "${RED}" "${RESET}" "${*}" >&2
	exit 1
}
Cleanup() { rm -f "$TMP_INSTALLER"; }
trap Cleanup EXIT INT TERM HUP

# --- Argument Parsing ---
SPECIFIED_TAG=""
# Keep track of original arguments to pass through
declare -a ORIGINAL_ARGS=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		--tag=*)
			SPECIFIED_TAG="${1#*=}"
			shift # Consume --tag=value
			;;
		--tag)
			# Handle --tag value format
			if [[ -z "${2:-}" || "$2" == -* ]]; then
				ErrorMessage "Option '--tag' requires a value (e.g., --tag=v0.4.3)." # Exits
			fi
			SPECIFIED_TAG="$2"
			shift 2 # Consume --tag and value
			;;
		*)
			# Assume any other argument is for the main install script
			ORIGINAL_ARGS+=("$1")
			shift
			;;
	esac
done

# --- Determine Target Tag ---
TARGET_TAG=""
if [[ -n "$SPECIFIED_TAG" ]]; then
	InfoMessage "Using specified tag: ${SPECIFIED_TAG}"
	TARGET_TAG="$SPECIFIED_TAG"
else
	InfoMessage "No specific tag provided, fetching latest release tag for ${OWNER_REPO}..."
	# Query GitHub API for the latest release
	LATEST_TAG=$(curl --silent "https://api.github.com/repos/${OWNER_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
	# Fallback: If 'latest' release isn't explicitly marked, try fetching the latest tag
	if [[ -z "$LATEST_TAG" ]]; then
		InfoMessage "No 'latest' release found via API, trying latest tag..."
		LATEST_TAG=$(curl --silent "https://api.github.com/repos/${OWNER_REPO}/tags" | grep '"name":' | sed -E 's/.*"([^"]+)".*/\1/' | sort -V | tail -n 1)
	fi
	if [[ -z "$LATEST_TAG" ]]; then
		ErrorMessage "Failed to determine the latest release/tag for ${OWNER_REPO}." # Exits
	fi
	InfoMessage "Latest release/tag identified as: ${LATEST_TAG}"
	TARGET_TAG="$LATEST_TAG"
fi

# --- Download Full Installer from Determined Tag ---
INSTALLER_URL="https://raw.githubusercontent.com/${OWNER_REPO}/${TARGET_TAG}/${FULL_INSTALLER_NAME}"
InfoMessage "Downloading installer script from tag ${TARGET_TAG}..."
if ! curl --fail --silent --show-error --location --output "$TMP_INSTALLER" "$INSTALLER_URL"; then
	ErrorMessage "Failed to download installer from: ${INSTALLER_URL}" # Exits
fi

# --- Execute Full Installer ---
InfoMessage "Executing the installer script (${FULL_INSTALLER_NAME} from ${TARGET_TAG})..."
chmod +x "$TMP_INSTALLER"

# Execute the downloaded script, passing the determined release tag
# and any other original arguments intended for the full installer.
bash "$TMP_INSTALLER" --release-tag="$TARGET_TAG" "${ORIGINAL_ARGS[@]}"

# Cleanup trap will remove the temp file on exit
exit 0 # Exit with the status of the executed installer

# EOF
