#!/usr/bin/env bash
# rcForge Stub Installer - Fetches and runs the installer from the latest release.
set -o nounset
set -o errexit
set -o pipefail

# --- Configuration ---
readonly OWNER_REPO="mhasse1/rcforge"
readonly FULL_INSTALLER_NAME="install-script.sh" # Name of the full script within the release
readonly TMP_INSTALLER="/tmp/rcforge_full_installer_$$"

# --- Utility Functions (Minimal) ---
InfoMessage() { echo "INFO: ${*}"; }
ErrorMessage() {
	echo "ERROR: ${*}" >&2
	exit 1
}
Cleanup() { rm -f "$TMP_INSTALLER"; }
trap Cleanup EXIT INT TERM

# --- Fetch Latest Tag ---
InfoMessage "Fetching latest release tag for ${OWNER_REPO}..."
LATEST_TAG=$(curl --silent "https://api.github.com/repos/${OWNER_REPO}/releases/latest" |
	grep '"tag_name":' |
	sed -E 's/.*"([^"]+)".*/\1/')

# Basic fallback - you might enhance this
if [[ -z "$LATEST_TAG" ]]; then
	InfoMessage "No 'latest' release found, trying latest tag..."
	LATEST_TAG=$(curl --silent "https://api.github.com/repos/${OWNER_REPO}/tags" |
		grep '"name":' |
		sed -E 's/.*"([^"]+)".*/\1/' |
		sort -V | tail -n 1)
fi

if [[ -z "$LATEST_TAG" ]]; then
	ErrorMessage "Failed to determine the latest release/tag for ${OWNER_REPO}."
fi
InfoMessage "Latest release/tag identified as: $LATEST_TAG"

# --- Download Full Installer from Release ---
INSTALLER_URL="https://raw.githubusercontent.com/${OWNER_REPO}/${LATEST_TAG}/${FULL_INSTALLER_NAME}"
InfoMessage "Downloading installer from ${LATEST_TAG}..."
if ! curl --fail --silent --location --output "$TMP_INSTALLER" "$INSTALLER_URL"; then
	ErrorMessage "Failed to download installer from: $INSTALLER_URL"
fi

# --- Execute Full Installer ---
InfoMessage "Executing the release-specific installer..."
chmod +x "$TMP_INSTALLER"
# Pass any arguments given to the stub script along to the full installer
bash "$TMP_INSTALLER" "$@"

# Cleanup trap will remove the temp file on exit
exit 0
