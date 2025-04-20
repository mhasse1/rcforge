#!/usr/bin/env bash
# install.sh - rcForge Stub Installer
# Author: rcForge Team
# Date: 2025-04-20
# Version: 0.5.0
# Description: Downloads the full installer ('install-script.sh') from a specific
#              GitHub release tag (if provided via --tag) or the latest release.
#              Executes the installer, passing the tag along.

# Set strict error handling
set -o nounset
set -o errexit
set -o pipefail

# Configuration
GITHUB_REPO="mhasse1/rcforge"
FULL_INSTALLER_NAME="install-script.sh"
TMP_INSTALLER="/tmp/rcforge_full_installer_$$"

# Clean up on exit
cleanup() {
	rm -f "$TMP_INSTALLER" &>/dev/null || true
}
trap cleanup EXIT INT TERM HUP

# Simple error handler
error_exit() {
	echo "ERROR: $1" >&2
	exit 1
}

# Parse arguments
SPECIFIED_TAG=""
PASS_THROUGH_ARGS=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		--tag=*)
			SPECIFIED_TAG="${1#*=}"
			shift
			;;
		--tag)
			if [[ -z "${2:-}" || "$2" == -* ]]; then
				error_exit "Option '--tag' requires a value (e.g., --tag=v0.5.0)."
			fi
			SPECIFIED_TAG="$2"
			shift 2
			;;
		*)
			# Pass through all other arguments to the main installer
			PASS_THROUGH_ARGS+=("$1")
			shift
			;;
	esac
done

# Determine target tag
if [[ -n "$SPECIFIED_TAG" ]]; then
	echo "Using specified tag: ${SPECIFIED_TAG}"
	TARGET_TAG="$SPECIFIED_TAG"
else
	echo "No specific tag provided, fetching latest release tag..."

	# Query GitHub API for the latest release
	LATEST_RELEASE=$(curl --silent "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")

	# Check if we got a valid response with a tag_name
	if [[ "$LATEST_RELEASE" == *"tag_name"* ]]; then
		TARGET_TAG=$(echo "$LATEST_RELEASE" | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
		echo "Latest release tag: $TARGET_TAG"
	else
		error_exit "Could not determine latest release. Please specify a tag with --tag or report this issue at: https://github.com/${GITHUB_REPO}/issues"
	fi
fi

# Download the full installer from the determined tag
INSTALLER_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${TARGET_TAG}/${FULL_INSTALLER_NAME}"
echo "Downloading installer from: $TARGET_TAG"

if ! curl --fail --silent --show-error --location --output "$TMP_INSTALLER" "$INSTALLER_URL"; then
	error_exit "Failed to download installer from: ${INSTALLER_URL}"
fi

# Make the installer executable
chmod +x "$TMP_INSTALLER"

# Execute the downloaded installer, passing the tag and other arguments
echo "Running installer..."
"$TMP_INSTALLER" --release-tag="$TARGET_TAG" "${PASS_THROUGH_ARGS[@]+"${PASS_THROUGH_ARGS[@]}"}"

# Cleanup handled by trap
echo "Installation completed."
exit 0
