#!/bin/bash
# build-deb.sh - Script to build the rcForge Debian package
set -e

# Default version if not specified
VERSION=${1:-"0.2.0"}
PACKAGE_NAME="rcforge"
BUILD_DIR="/tmp/rcforge-build-$VERSION"
REPO_DIR=$(pwd)

# Check if we're in the right directory
if [[ ! -f "rcforge.sh" ]]; then
    echo "Error: This script must be run from the root of the rcForge repository."
    exit 1
fi

# Check for required tools
for cmd in debuild dh_make; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: Required tool $cmd not found."
        echo "Please install the build dependencies:"
        echo "  sudo apt install debhelper devscripts dh-make"
        exit 1
    fi
done

echo "Building rcForge $VERSION Debian package..."

# Create temporary build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Copy files to build directory
echo "Copying files to build directory..."
cp -r "$REPO_DIR"/* "$BUILD_DIR/"

# Clean up any previous build artifacts
cd "$BUILD_DIR"
rm -rf debian

# Initialize Debian packaging files
echo "Initializing Debian packaging..."
dh_make --native --single --packagename "${PACKAGE_NAME}_${VERSION}" \
        --email "mark@analogedge.com" --copyright expat --yes

# Replace generated files with our custom ones
echo "Customizing Debian package configuration..."

# Remove the compat file if it exists
if [[ -f debian/compat ]]; then
    rm debian/compat
fi

# Build the package with architecture-independent flag
echo "Building Debian package..."
debuild -us -uc -ai

# Move the built package to the parent directory
echo "Moving package to parent directory..."
cd ..
mv "${PACKAGE_NAME}_${VERSION}_all.deb" "$REPO_DIR/"

echo "Package built successfully:"
echo "$REPO_DIR/${PACKAGE_NAME}_${VERSION}_all.deb"

# Clean up
echo "Cleaning up build directory..."
rm -rf "$BUILD_DIR"

echo "Done!"
# EOF
