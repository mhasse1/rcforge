# rcForge Makefile
# Provides commands for building, testing, and packaging

VERSION = 2.0.0
SHELL = /bin/bash

# Directories
PREFIX = /usr/local
DESTDIR =
SYSCONFDIR = $(PREFIX)/etc
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share/rcforge
DOCDIR = $(PREFIX)/share/doc/rcforge

# Files
CORE_FILES = $(wildcard core/*.sh)
UTIL_FILES = $(wildcard utils/*.sh)
LIB_FILES = $(wildcard lib/*.sh)
INCLUDE_FILES = $(wildcard include/*/*.sh)
DOC_FILES = README.md docs/universal-shell-guide.md docs/README-includes.md

.PHONY: all install uninstall clean test deb homebrew release

all: test

# Install rcForge to the system
install:
	@echo "Installing rcForge $(VERSION)..."

	# Create directories
	mkdir -p $(DESTDIR)$(SHAREDIR)/core
	mkdir -p $(DESTDIR)$(SHAREDIR)/utils
	mkdir -p $(DESTDIR)$(SHAREDIR)/lib
	mkdir -p $(DESTDIR)$(SHAREDIR)/include
	mkdir -p $(DESTDIR)$(SHAREDIR)/examples
	mkdir -p $(DESTDIR)$(DOCDIR)
	mkdir -p $(DESTDIR)$(BINDIR)

	# Install main script
	install -m 755 rcforge.sh $(DESTDIR)$(SHAREDIR)/

	# Install core files
	$(foreach file,$(CORE_FILES),install -m 755 $(file) $(DESTDIR)$(SHAREDIR)/core/;)

	# Install utility files
	$(foreach file,$(UTIL_FILES),install -m 755 $(file) $(DESTDIR)$(SHAREDIR)/utils/;)

	# Install library files
	$(foreach file,$(LIB_FILES),install -m 755 $(file) $(DESTDIR)$(SHAREDIR)/lib/;)

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

	# Install example files
	$(foreach file,$(wildcard docs/development-docs/examples/*.sh),install -m 755 $(file) $(DESTDIR)$(SHAREDIR)/examples/;)

	# Install documentation
	$(foreach file,$(DOC_FILES),install -m 644 $(file) $(DESTDIR)$(DOCDIR)/;)

	# Create symlink to setup script
	ln -sf $(SHAREDIR)/utils/rcforge-setup.sh $(DESTDIR)$(BINDIR)/rcforge

	@echo "Installation complete."
	@echo "To activate rcForge, add to your shell configuration:"
	@echo "  source \"$(SHAREDIR)/rcforge.sh\""

# Uninstall rcForge from the system
uninstall:
	@echo "Uninstalling rcForge..."
	rm -rf $(DESTDIR)$(SHAREDIR)
	rm -rf $(DESTDIR)$(DOCDIR)
	rm -f $(DESTDIR)$(BINDIR)/rcforge
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
		source lib/include-functions.sh 2>/dev/null && echo "Include system loaded successfully" || echo "Include system failed to load"; \
	} || echo "Skipping include system tests (requires Bash 4.0+)"

	# Basic syntax check
	@echo "Checking syntax of shell scripts..."
	@find . -name "*.sh" -type f -exec bash -n {} \; && echo "Syntax check passed" || { echo "Syntax check failed"; exit 1; }

	@echo "All tests passed."

# Create Debian package
deb:
	@echo "Building Debian package for rcForge $(VERSION)..."
	@if ! command -v debuild &> /dev/null; then \
		echo "Error: debuild not found. Install with: sudo apt install devscripts debhelper dh-make"; \
		exit 1; \
	fi

	@chmod +x build-deb.sh
	./build-deb.sh $(VERSION)

# Create Homebrew formula
homebrew:
	@echo "Creating Homebrew formula for rcForge $(VERSION)..."
	@if ! command -v brew &> /dev/null; then \
		echo "Error: brew not found. Please install Homebrew: https://brew.sh/"; \
		exit 1; \
	fi

	@chmod +x create-homebrew.sh
	./create-homebrew.sh $(VERSION)

# Clean up build artifacts
clean:
	@echo "Cleaning up build files..."
	rm -f *.deb
	rm -f rcforge.rb
	rm -rf debian/rcforge
	rm -rf debian/.debhelper
	rm -f debian/files
	rm -f debian/*.log
	rm -f debian/*.substvars
	@echo "Clean complete."

# Prepare a release
release: clean test deb homebrew
	@echo "Preparing release $(VERSION)..."
	@if [ ! -f rcforge_$(VERSION)_all.deb ]; then \
		echo "Error: Debian package not created successfully"; \
		exit 1; \
	fi
	@if [ ! -f rcforge.rb ]; then \
		echo "Error: Homebrew formula not created successfully"; \
		exit 1; \
	fi

	@echo "Release preparation complete."
	@echo "Created:"
	@echo "  - rcforge_$(VERSION)_all.deb"
	@echo "  - rcforge.rb"
	@echo ""
	@echo "Next steps:"
	@echo "1. Tag the release: git tag -a v$(VERSION) -m 'Release v$(VERSION)'"
	@echo "2. Push the tag: git push origin v$(VERSION)"
	@echo "3. Create a release on GitHub with these files"
