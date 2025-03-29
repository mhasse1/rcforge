# rcForge Makefile
# Provides commands for building, testing, and packaging

VERSION = 0.2.0
SHELL = /bin/bash

# Directories
PREFIX = /usr/local
DESTDIR = 
SYSCONFDIR = $(PREFIX)/etc
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share/rcforge
DOCDIR = $(PREFIX)/share/doc/rcforge
LIBDIR = $(PREFIX)/lib/rcforge

# Files
CORE_FILES = $(wildcard core/*.sh)
UTIL_FILES = $(wildcard utils/*.sh)
LIB_FILES = $(wildcard src/lib/*.sh)
INCLUDE_FILES = $(wildcard include/*/*.sh)
DOC_FILES = README.md $(wildcard docs/*.md) $(wildcard docs/*/*.md)

.PHONY: all install uninstall clean test deb homebrew release

all: test

# Install rcForge to the system
install:
	@echo "Installing rcForge $(VERSION)..."
	
	# Create directories
	mkdir -p $(DESTDIR)$(SHAREDIR)/core
	mkdir -p $(DESTDIR)$(SHAREDIR)/utils
	mkdir -p $(DESTDIR)$(LIBDIR)
	mkdir -p $(DESTDIR)$(SHAREDIR)/include
	mkdir -p $(DESTDIR)$(SHAREDIR)/scripts
	mkdir -p $(DESTDIR)$(SHAREDIR)/exports
	mkdir -p $(DESTDIR)$(DOCDIR)
	mkdir -p $(DESTDIR)$(BINDIR)
	
	# Install main script
	install -m 755 rcforge.sh $(DESTDIR)$(SHAREDIR)/
	install -m 755 include-structure.sh $(DESTDIR)$(SHAREDIR)/
	
	# Install core files
	$(foreach file,$(CORE_FILES),install -m 755 $(file) $(DESTDIR)$(SHAREDIR)/core/;)
	
	# Install utility files
	$(foreach file,$(UTIL_FILES),install -m 755 $(file) $(DESTDIR)$(SHAREDIR)/utils/;)
	
	# Install library files
	mkdir -p $(DESTDIR)$(LIBDIR)
	$(foreach file,$(LIB_FILES),install -m 755 $(file) $(DESTDIR)$(LIBDIR)/;)
	
	# Install include files (with directory structure)
	@for dir in include/*; do \
		if [ -d "$$dir" ]; then \
			mkdir -p $(DESTDIR)$(SHAREDIR)/$$dir; \
			for file in $$dir/*.sh; do \
				if [ -f "$$file" ]; then \
					install -m 755 $$file $(DESTDIR)$(SHAREDIR)/$$dir/; \
				fi; \
			done; \
		fi; \
	done
	
	# Install example configuration files
	$(foreach file,$(wildcard scripts/*.sh),install -m 755 $(file) $(DESTDIR)$(SHAREDIR)/scripts/;)
	
	# Install documentation
	$(foreach file,$(DOC_FILES),install -m 644 $(file) $(DESTDIR)$(DOCDIR)/;)
	
	# Create symlink to main script in bin directory
	ln -sf $(SHAREDIR)/rcforge.sh $(DESTDIR)$(BINDIR)/rcforge
	
	# Create symlink to setup script
	ln -sf $(SHAREDIR)/utils/rcforge-setup.sh $(DESTDIR)$(BINDIR)/rcforge-setup
	
	@echo "Installation complete."
	@echo "To activate rcForge, add to your shell configuration:"
	@echo "  source \"$(SHAREDIR)/rcforge.sh\""

# Install rcForge to the user's home directory
install-user:
	@echo "Installing rcForge $(VERSION) to user's home directory..."
	
	# Create user directories
	mkdir -p $(HOME)/.config/rcforge/scripts
	mkdir -p $(HOME)/.config/rcforge/include
	mkdir -p $(HOME)/.config/rcforge/exports
	mkdir -p $(HOME)/.config/rcforge/docs
	
	# Install main script
	install -m 755 rcforge.sh $(HOME)/.config/rcforge/
	install -m 755 include-structure.sh $(HOME)/.config/rcforge/
	
	# Install core files
	mkdir -p $(HOME)/.config/rcforge/core
	$(foreach file,$(CORE_FILES),install -m 755 $(file) $(HOME)/.config/rcforge/core/;)
	
	# Install utility files
	mkdir -p $(HOME)/.config/rcforge/utils
	$(foreach file,$(UTIL_FILES),install -m 755 $(file) $(HOME)/.config/rcforge/utils/;)
	
	# Install library files
	mkdir -p $(HOME)/.config/rcforge/src/lib
	$(foreach file,$(LIB_FILES),install -m 755 $(file) $(HOME)/.config/rcforge/src/lib/;)
	
	# Set up include directories
	bash $(HOME)/.config/rcforge/include-structure.sh
	
	# Install example configuration files
	$(foreach file,$(wildcard scripts/*.sh),install -m 755 $(file) $(HOME)/.config/rcforge/scripts/;)
	
	# Install documentation
	$(foreach file,$(DOC_FILES),install -m 644 $(file) $(HOME)/.config/rcforge/docs/;)
	
	@echo "User installation complete."
	@echo "To activate rcForge, add to your shell configuration:"
	@echo "  source \"$(HOME)/.config/rcforge/rcforge.sh\""

# Uninstall rcForge from the system
uninstall:
	@echo "Uninstalling rcForge..."
	rm -rf $(DESTDIR)$(SHAREDIR)
	rm -rf $(DESTDIR)$(LIBDIR)
	rm -rf $(DESTDIR)$(DOCDIR)
	rm -f $(DESTDIR)$(BINDIR)/rcforge
	rm -f $(DESTDIR)$(BINDIR)/rcforge-setup
	@echo "rcForge has been uninstalled."
	@echo "User configuration files in ~/.config/rcforge have not been removed."

# Run tests
test:
	@echo "Running rcForge tests..."
	# Check if core files exist
	@test -f rcforge.sh || { echo "Error: rcforge.sh not found"; exit 1; }
	@test -d core || { echo "Error: core directory not found"; exit 1; }
	@test -d utils || { echo "Error: utils directory not found"; exit 1; }
	
	# Test include system if on Bash 4.0+
	@bash --version | grep -q 'version [4-9]' && { \
		echo "Testing include system..."; \
		source src/lib/include-functions.sh 2>/dev/null && echo "Include system loaded successfully" || echo "Include system failed to load"; \
	} || echo "Skipping include system tests (requires Bash 4.0+)"
	
	# Basic syntax check
	@echo "Checking syntax of shell scripts..."
	@find . -name "*.sh" -type f -exec bash -n {} \; && echo "Syntax check passed" || { echo "Syntax check failed"; exit 1; }
	
	@echo "All tests passed."

# Create Debian package
deb:
	@echo "Building Debian package for rcForge $(VERSION)..."
	@if ! command -v dpkg-buildpackage >/dev/null 2>&1; then \
		echo "Error: dpkg-buildpackage not found. Install with: sudo apt install devscripts debhelper"; \
		exit 1; \
	fi
	
	dpkg-buildpackage -us -uc -b
	@echo "Debian package built successfully."

# Create Homebrew formula
homebrew:
	@echo "Creating Homebrew formula for rcForge $(VERSION)..."
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "Error: brew not found. Please install Homebrew: https://brew.sh/"; \
		exit 1; \
	fi
	
	# Create Formula directory if it doesn't exist
	mkdir -p Formula
	
	# Create tarball for formula
	mkdir -p packaging/dist
	git archive --prefix=rcforge-$(VERSION)/ -o packaging/dist/rcforge-$(VERSION).tar.gz HEAD || \
	  tar -czf packaging/dist/rcforge-$(VERSION).tar.gz --transform "s,^,rcforge-$(VERSION)/," \
	    --exclude=".git" --exclude="packaging/dist" --exclude=".DS_Store" .
	
	# Calculate SHA256
	SHA256=$$(shasum -a 256 packaging/dist/rcforge-$(VERSION).tar.gz | cut -d' ' -f1)
	
	# Update formula with correct SHA256
	sed "s/REPLACE_WITH_ACTUAL_SHA256/$$SHA256/" Formula/rcforge.rb.template > Formula/rcforge.rb
	
	@echo "Homebrew formula created: Formula/rcforge.rb"
	@echo "To install locally: brew install --build-from-source Formula/rcforge.rb"
	@echo "To create a tap: brew tap-new <username>/rcforge && cp Formula/rcforge.rb <tap-path>/Formula/"

# Clean up build artifacts
clean:
	@echo "Cleaning up build files..."
	rm -rf packaging/dist
	rm -f Formula/rcforge.rb
	rm -f *.deb
	rm -rf debian/.debhelper
	rm -f debian/files
	rm -f debian/*.log
	rm -f debian/*.substvars
	rm -rf debian/rcforge
	@echo "Clean complete."

# Prepare a release
release: clean test
	@echo "Preparing release $(VERSION)..."
	
	# Create distribution directory
	mkdir -p packaging/dist
	
	# Create source tarball
	git archive --prefix=rcforge-$(VERSION)/ -o packaging/dist/rcforge-$(VERSION).tar.gz HEAD || \
	  tar -czf packaging/dist/rcforge-$(VERSION).tar.gz --transform "s,^,rcforge-$(VERSION)/," \
	    --exclude=".git" --exclude="packaging/dist" --exclude=".DS_Store" .
	
	# Create Debian package
	$(MAKE) deb
	
	# Create Homebrew formula
	$(MAKE) homebrew
	
	# Create installation script package
	mkdir -p packaging/dist/install
	cp rcforge.sh packaging/dist/install/
	cp -r core packaging/dist/install/
	cp -r utils packaging/dist/install/
	cp -r src packaging/dist/install/
	cp -r include packaging/dist/install/
	tar -czf packaging/dist/rcforge-$(VERSION)-install.tar.gz -C packaging/dist install
	
	@echo "Release $(VERSION) prepared. Distribution files are in packaging/dist/"
	@echo "  - Source tarball: packaging/dist/rcforge-$(VERSION).tar.gz"
	@echo "  - Debian package: ../rcforge_$(VERSION)_all.deb"
	@echo "  - Homebrew formula: Formula/rcforge.rb"
	@echo "  - Install package: packaging/dist/rcforge-$(VERSION)-install.tar.gz"
# EOF
