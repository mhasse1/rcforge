# Variables
VERSION := 2.0.0 # Replace with your project's version
TARBALL := rcforge-$(VERSION).tar.gz
FORMULA := rcforge.rb
GITHUB_URL := https://github.com/mhasse1/rcforge # Replace with your GitHub URL
RELEASE_URL := $(GITHUB_URL)/archive/refs/tags/v$(VERSION).tar.gz

# Default target
all: tarball checksum formula

# Create the release tarball
tarball:
	@echo "Creating tarball: $(TARBALL)"
	git archive --format=tar.gz --output=$(TARBALL) v$(VERSION)
	@echo "Tarball created successfully."

# Calculate the SHA256 checksum
checksum: tarball
	@echo "Calculating SHA256 checksum..."
	SHA256 := $(shell shasum -a 256 $(TARBALL) | awk '{print $$1}')
	@echo "SHA256: $(SHA256)"
	@echo "Checksum calculation complete."
	# You might want to store the SHA256 in a file or variable for later use in the formula

# Generate the Homebrew formula
formula: checksum
	@echo "Generating Homebrew formula: $(FORMULA)"
	# This is a simplified example. You'll likely need a more robust templating solution
	# (e.g., `sed`, or a templating language) for complex formulas.
	echo "class Rcforge < Formula" > $(FORMULA)
	echo "  desc \"A flexible, modular configuration system for Bash and Zsh shells\"" >> $(FORMULA)
	echo "  homepage \"$(GITHUB_URL)\"" >> $(FORMULA)
	echo "  url \"$(RELEASE_URL)\"" >> $(FORMULA)
	echo "  sha256 \"$(SHA256)\"" >> $(FORMULA)
	echo "  def install" >> $(FORMULA)
	echo "    prefix.install Dir[\"*\"]" >> $(FORMULA)
	echo "  end" >> $(FORMULA)
	echo "  def caveats" >> $(FORMULA)
	echo "    <<~EOS" >> $(FORMULA)
	echo "      To enable rcForge, add the following line to your ~/.bashrc or ~/.zshrc:" >> $(FORMULA)
	echo "        source \"#{opt_share}/rcforge/rcforge.sh\"" >> $(FORMULA)
	echo "    EOS" >> $(FORMULA)
	echo "  end" >> $(FORMULA)
	echo "  test do" >> $(FORMULA)
	echo "    system \"false\"" >> $(FORMULA)
	echo "  end" >> $(FORMULA)
	echo "end" >> $(FORMULA)
	@echo "Formula generated successfully."

# Clean up generated files
clean:
	@echo "Cleaning up..."
	rm -f $(TARBALL) $(FORMULA)
	@echo "Cleanup complete."
