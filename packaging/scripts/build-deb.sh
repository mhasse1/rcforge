#!/bin/bash
# build-deb.sh - Script to build the rcForge Debian package
# Usage: ./build-deb.sh [version]
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
dh_make --native --single --packagename "${PACKAGE_NAME}_${VERSION}" --email "your.email@example.com" --copyright mit --yes

# Replace generated debian files with our custom ones
echo "Setting up Debian package configuration..."

# Control file
cat > debian/control << EOF
Package: rcforge
Version: $VERSION
Section: utils
Priority: optional
Architecture: all
Depends: bash (>= 4.0), coreutils
Recommends: git
Suggests: zsh
Maintainer: Your Name <your.email@example.com>
Description: Universal shell configuration manager
 rcForge is a flexible, modular configuration system for Bash and Zsh shells
 that provides a unified framework for managing shell environments across
 multiple machines.
 .
 Features:
  * Cross-shell compatibility with Bash and Zsh
  * Machine-specific configurations based on hostname
  * Deterministic loading order with explicit sequence numbers
  * Conflict detection and resolution
  * Visual configuration diagrams
  * Checksum verification for shell RC files
  * Modular function include system
  .
 Currently in version $VERSION (pre-release)
EOF

# Rules file
cat > debian/rules << 'EOF'
#!/usr/bin/make -f
# -*- makefile -*-

# Uncomment this to turn on verbose mode.
#export DH_VERBOSE=1

%:
	dh $@

override_dh_auto_install:
	# Create directory structure
	mkdir -p debian/rcforge/usr/share/rcforge
	mkdir -p debian/rcforge/usr/share/rcforge/include
	mkdir -p debian/rcforge/usr/share/rcforge/lib
	mkdir -p debian/rcforge/usr/share/rcforge/examples
	mkdir -p debian/rcforge/usr/share/doc/rcforge
	mkdir -p debian/rcforge/usr/bin

	# Install core files
	cp -r core/* debian/rcforge/usr/share/rcforge/
	cp rcforge.sh debian/rcforge/usr/share/rcforge/
	cp -r src/lib/* debian/rcforge/usr/share/rcforge/lib/
	
	# Install include files
	cp -r include/* debian/rcforge/usr/share/rcforge/include/
	
	# Install examples
	cp docs/development-docs/examples/*.sh debian/rcforge/usr/share/rcforge/examples/
	
	# Install utilities
	cp utils/*.sh debian/rcforge/usr/share/rcforge/
	
	# Install documentation
	cp README.md debian/rcforge/usr/share/doc/rcforge/
	cp docs/user-guides/*.md debian/rcforge/usr/share/doc/rcforge/
	cp docs/README-includes.md debian/rcforge/usr/share/doc/rcforge/
	
	# Create executable symlink
	ln -s /usr/share/rcforge/rcforge-setup.sh debian/rcforge/usr/bin/rcforge

override_dh_fixperms:
	dh_fixperms
	# Make scripts executable
	chmod +x debian/rcforge/usr/share/rcforge/*.sh
	chmod +x debian/rcforge/usr/share/rcforge/lib/*.sh
	chmod +x debian/rcforge/usr/bin/rcforge
EOF
chmod +x debian/rules

# Post-install script
cat > debian/postinst << 'EOF'
#!/bin/bash
set -e

# Create directory structure for user configuration if it doesn't exist
if [ "$1" = "configure" ]; then
    echo "Setting up rcForge..."
    
    # Create user configuration examples
    for user_home in /home/*; do
        # Skip if not a directory or no login shell
        [ ! -d "$user_home" ] && continue
        user=$(basename "$user_home")
        
        # Skip system users
        if [ $(id -u "$user" 2>/dev/null || echo 0) -ge 1000 ]; then
            USER_DIR="$user_home/.config/rcforge"
            
            # Create user directories only if they don't exist
            if [ ! -d "$USER_DIR" ]; then
                echo "Creating configuration directory for user: $user"
                
                # Create with proper permissions
                mkdir -p "$USER_DIR/scripts" "$USER_DIR/include" "$USER_DIR/exports" "$USER_DIR/docs"
                chown -R "$user:$user" "$USER_DIR"
                
                # Create README
                cp /usr/share/doc/rcforge/README.md "$USER_DIR/docs/"
                chown "$user:$user" "$USER_DIR/docs/README.md"
                
                # Copy example configurations if they don't exist
                if [ ! -f "$USER_DIR/scripts/100_global_common_environment.sh" ]; then
                    cp /usr/share/rcforge/examples/*.sh "$USER_DIR/scripts/"
                    chown "$user:$user" "$USER_DIR/scripts/"*.sh
                    chmod +x "$USER_DIR/scripts/"*.sh
                fi
            fi
        fi
    done
    
    echo "rcForge installation complete."
    echo ""
    echo "To activate rcForge in your shell:"
    echo "  echo 'source \"/usr/share/rcforge/rcforge.sh\"' >> ~/.bashrc"
    echo "  # or for Zsh"
    echo "  echo 'source \"/usr/share/rcforge/rcforge.sh\"' >> ~/.zshrc"
    echo ""
    echo "Then restart your shell or run: source ~/.bashrc (or ~/.zshrc)"
fi

exit 0
EOF
chmod +x debian/postinst

# Pre-removal script
cat > debian/prerm << 'EOF'
#!/bin/bash
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    echo "Removing rcForge system files..."
    
    # Note: We don't remove user configuration files in ~/.config/rcforge
    # This preserves user customizations even if they reinstall later
    
    if [ "$1" = "purge" ]; then
        echo "Note: User configuration files in ~/.config/rcforge are preserved."
        echo "To completely remove all rcForge files, users should manually delete:"
        echo "  ~/.config/rcforge"
    fi
fi

exit 0
EOF
chmod +x debian/prerm

# Create changelog if it doesn't exist
if [[ ! -f CHANGELOG.md ]]; then
    echo "Creating changelog..."
    cat > CHANGELOG.md << EOF
rcforge ($VERSION) unstable; urgency=medium

  * Initial release of rcForge $VERSION
  * Implemented modular include system
  * Added support for system-level and user-level configurations
  * Added Bash 4.0+ requirement with version checking

 -- Your Name <your.email@example.com>  $(date -R)
EOF
fi

# Build the package
echo "Building Debian package..."
debuild -us -uc

# Move the built package to the parent directory
echo "Moving package to parent directory..."
cd ..
mv rcforge_${VERSION}_*.deb "$REPO_DIR/"

echo "Package built successfully:"
echo "$REPO_DIR/rcforge_${VERSION}_all.deb"

# Clean up
echo "Cleaning up build directory..."
rm -rf "$BUILD_DIR"

echo "Done!"
# EOF
