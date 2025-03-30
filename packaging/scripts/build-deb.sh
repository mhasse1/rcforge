#!/bin/bash
# build-deb.sh - Script to build the rcForge Debian package
# Author: Mark Hasse
# Date: 2025-03-29

set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color

# Default version if not specified
VERSION=${1:-"0.2.0"}
PACKAGE_NAME="rcforge"
BUILD_DIR="/tmp/rcforge-build-$VERSION"
REPO_DIR=$(pwd)

# Check if we're in the right directory
if [[ ! -f "rcforge.sh" ]]; then
    echo -e "${RED}Error: This script must be run from the root of the rcForge repository.${RESET}"
    exit 1
fi

# Check for required tools
for cmd in dpkg-deb fakeroot; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: Required tool $cmd not found.${RESET}"
        echo "Please install the build dependencies:"
        echo "  sudo apt install dpkg fakeroot"
        exit 1
    fi
done

echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│ Building rcForge $VERSION Debian Package             │${RESET}"
echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
echo ""

# Create temporary build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create package directory structure
echo -e "${CYAN}Creating package directory structure...${RESET}"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/share/rcforge"
mkdir -p "$BUILD_DIR/usr/share/rcforge/core"
mkdir -p "$BUILD_DIR/usr/share/rcforge/utils"
mkdir -p "$BUILD_DIR/usr/share/rcforge/lib"
mkdir -p "$BUILD_DIR/usr/share/rcforge/include"
mkdir -p "$BUILD_DIR/usr/share/rcforge/examples"
mkdir -p "$BUILD_DIR/usr/share/doc/rcforge"
mkdir -p "$BUILD_DIR/usr/bin"

# Copy files to package directory
echo -e "${CYAN}Copying files to package directory...${RESET}"

# Copy main script
cp "$REPO_DIR/rcforge.sh" "$BUILD_DIR/usr/share/rcforge/"
cp "$REPO_DIR/include-structure.sh" "$BUILD_DIR/usr/share/rcforge/"

# Copy core files
if [[ -d "$REPO_DIR/core" ]]; then
    cp -r "$REPO_DIR/core/"* "$BUILD_DIR/usr/share/rcforge/core/"
fi

# Copy utility files
if [[ -d "$REPO_DIR/utils" ]]; then
    cp -r "$REPO_DIR/utils/"* "$BUILD_DIR/usr/share/rcforge/utils/"
fi

# Copy library files
if [[ -d "$REPO_DIR/lib" ]]; then
    cp -r "$REPO_DIR/lib/"* "$BUILD_DIR/usr/share/rcforge/lib/"
fi

# Copy include files (preserving directory structure) if they exist
if [[ -d "$REPO_DIR/include" ]]; then
    cp -r "$REPO_DIR/include/"* "$BUILD_DIR/usr/share/rcforge/include/" 2>/dev/null || true
else
    # Create basic include directory structure
    mkdir -p "$BUILD_DIR/usr/share/rcforge/include/path"
    mkdir -p "$BUILD_DIR/usr/share/rcforge/include/common"
    mkdir -p "$BUILD_DIR/usr/share/rcforge/include/git"
    mkdir -p "$BUILD_DIR/usr/share/rcforge/include/system"
    # Create placeholder README
    echo "# rcForge Include System
This directory contains modular functions for the rcForge include system." > "$BUILD_DIR/usr/share/rcforge/include/README.md"
fi

# Copy example scripts
if [[ -d "$REPO_DIR/scripts" ]]; then
    cp -r "$REPO_DIR/scripts/"* "$BUILD_DIR/usr/share/rcforge/examples/" 2>/dev/null || true
elif [[ -d "$REPO_DIR/docs/development-docs/examples" ]]; then
    # Fallback to examples in docs directory
    mkdir -p "$BUILD_DIR/usr/share/rcforge/examples/"
    cp -r "$REPO_DIR/docs/development-docs/examples/"*.sh "$BUILD_DIR/usr/share/rcforge/examples/" 2>/dev/null || true
fi

# Copy documentation
cp "$REPO_DIR/README.md" "$BUILD_DIR/usr/share/doc/rcforge/"
if [[ -d "$REPO_DIR/docs" ]]; then
    # Copy primary documentation
    if [[ -d "$REPO_DIR/docs/user-guides" ]]; then
        cp -r "$REPO_DIR/docs/user-guides/"*.md "$BUILD_DIR/usr/share/doc/rcforge/"
    fi

    # Copy other important docs
    cp "$REPO_DIR/docs/README-includes.md" "$BUILD_DIR/usr/share/doc/rcforge/" 2>/dev/null || true
fi

# Copy LICENSE if it exists
if [[ -f "$REPO_DIR/LICENSE" ]]; then
    cp "$REPO_DIR/LICENSE" "$BUILD_DIR/usr/share/doc/rcforge/"
fi

# Create executable wrapper script instead of symlink
cat > "$BUILD_DIR/usr/bin/rcforge" << 'EOF'
#!/bin/bash
# rcforge wrapper script
# This script runs the rcforge-setup.sh from the system installation

# Find the setup script
SETUP_SCRIPT="/usr/share/rcforge/utils/rcforge-setup.sh"

# Check if it exists
if [ ! -f "$SETUP_SCRIPT" ]; then
    echo "Error: rcforge setup script not found at $SETUP_SCRIPT"
    exit 1
fi

# Execute the setup script with all arguments
exec "$SETUP_SCRIPT" "$@"
EOF
chmod 755 "$BUILD_DIR/usr/bin/rcforge"

# Set file permissions
echo -e "${CYAN}Setting file permissions...${RESET}"
find "$BUILD_DIR/usr/share/rcforge" -name "*.sh" -type f -exec chmod 755 {} \;
chmod 755 "$BUILD_DIR/usr/bin/rcforge"

# Create DEBIAN control files
echo -e "${CYAN}Creating Debian control files...${RESET}"

# Control file
cat > "$BUILD_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: shells
Priority: optional
Architecture: all
Depends: bash (>= 4.0)
Recommends: zsh
Maintainer: Mark Hasse <mark@analogedge.com>
Homepage: https://github.com/mhasse1/rcforge
Description: Universal shell configuration system for Bash and Zsh
 rcForge is a flexible, modular configuration system for Bash and Zsh shells
 that provides a single framework for managing shell environments across
 multiple machines.
 .
 Key features:
  * Cross-shell compatibility
  * Machine-specific configurations
  * Deterministic loading order
  * Conflict detection
  * Include system for modular functions
 .
 Currently in version $VERSION (pre-release)
EOF

# Make sure they're executable
chmod 755 "$BUILD_DIR/DEBIAN/postinst"
chmod 755 "$BUILD_DIR/DEBIAN/prerm"

# Build the package
echo -e "${CYAN}Building the Debian package...${RESET}"
fakeroot dpkg-deb --build "$BUILD_DIR" "$REPO_DIR/${PACKAGE_NAME}_${VERSION}_all.deb"

# Check if the package was built successfully
if [[ -f "$REPO_DIR/${PACKAGE_NAME}_${VERSION}_all.deb" ]]; then
    echo -e "${GREEN}✓ Package built successfully: ${YELLOW}${PACKAGE_NAME}_${VERSION}_all.deb${RESET}"

    # Display package information
    echo -e "${CYAN}Package information:${RESET}"
    dpkg-deb --info "$REPO_DIR/${PACKAGE_NAME}_${VERSION}_all.deb"

    # Cleanup
    echo -e "${CYAN}Cleaning up build files...${RESET}"
    rm -rf "$BUILD_DIR"
else
    echo -e "${RED}× Failed to build package.${RESET}"
    exit 1
fi

echo -e "${GREEN}Build complete! Package is ready for distribution.${RESET}"
echo "To install the package on Debian/Ubuntu systems:"
echo "  sudo dpkg -i ${PACKAGE_NAME}_${VERSION}_all.deb"
echo "  sudo apt install -f  # To resolve any dependencies"
# EOF