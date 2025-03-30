#!/bin/bash
# brew-test-local.sh - Test rcForge Homebrew formula locally
# Copyright: Analog Edge LLC
# Date: March 28, 2025

set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color

# Detect script directory and parent
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect project root dynamically
detect_project_root() {
  local possible_roots=(
    "${RCFORGE_ROOT}"                  # Explicitly set environment variable
    "$(dirname "$(dirname "$SCRIPT_DIR")")" # Grandparent of script directory
    "$HOME/src/rcforge"                # Common developer location
    "$HOME/Projects/rcforge"           # Alternative project location
    "$HOME/Development/rcforge"        # Another alternative
  )

  for dir in "${possible_roots[@]}"; do
    if [[ -n "$dir" && -d "$dir" && -f "$dir/rcforge.sh" ]]; then
      echo "$dir"
      return 0
    fi
  done

  echo ""
  return 1
}

# Base directories
PROJECT_ROOT=$(detect_project_root)
if [[ -z "$PROJECT_ROOT" ]]; then
  echo -e "${RED}Error: Could not detect project root. Please specify RCFORGE_ROOT.${RESET}"
  exit 1
fi

BUILD_DIR="/tmp/rcforge-build"
VERSION="0.2.0"  # Should be kept in sync with project version
TAP_NAME="analog-edge/homebrew-rcforge"
FORMULA_NAME="rcforge"
FORMULA_PATH="Formula/rcforge.rb"
LOCAL_TAP_DIR="$(brew --repository)/Library/Taps/analog-edge/homebrew-rcforge"
TEST_LOG="/tmp/rcforge-brew-test.log"

echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│ rcForge Homebrew Formula Test                        │${RESET}"
echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
echo ""

# Check that we're in the right directory
if [[ ! -f "$PROJECT_ROOT/rcforge.sh" ]]; then
    echo -e "${RED}Error: rcforge.sh not found in project root.${RESET}"
    echo "Project root: $PROJECT_ROOT"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Function to create a tarball of the project for testing
create_tarball() {
    echo -e "${CYAN}Creating project tarball for testing...${RESET}"

    # Define exclusion patterns to ensure a clean release tarball
    EXCLUDES=(
        ".git"
        ".github"
        ".DS_Store"
        "*/.DS_Store"
        "packaging/scripts/test-*"
        "tmp/*"
        ".gitignore"
    )

    # Build exclude arguments for tar
    EXCLUDE_ARGS=""
    for PATTERN in "${EXCLUDES[@]}"; do
        EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=$PATTERN"
    done

    # Create the tarball
    TAR_PATH="$BUILD_DIR/rcforge-$VERSION.tar.gz"
    tar $EXCLUDE_ARGS -czf "$TAR_PATH" -C "$PROJECT_ROOT" .

    # Calculate SHA256 for the tarball
    SHA256=$(shasum -a 256 "$TAR_PATH" | awk '{print $1}')

    echo -e "${GREEN}Created tarball: ${YELLOW}$TAR_PATH${RESET}"
    echo -e "${GREEN}SHA256: ${YELLOW}$SHA256${RESET}"

    # Store for later use
    echo "$TAR_PATH" > "$BUILD_DIR/tarball_path"
    echo "$SHA256" > "$BUILD_DIR/tarball_sha256"
}

# Function to create or update local tap
setup_local_tap() {
    echo -e "${CYAN}Setting up local tap...${RESET}"

    # Check if tap exists
    if brew tap | grep -q "$TAP_NAME"; then
        echo -e "${YELLOW}Tap $TAP_NAME already exists.${RESET}"
    else
        # Create new tap
        brew tap-new "$TAP_NAME"
        echo -e "${GREEN}Created new tap: $TAP_NAME${RESET}"
    fi

    # Ensure Formula directory exists in the tap
    mkdir -p "$LOCAL_TAP_DIR/Formula"

    echo -e "${GREEN}Local tap setup complete.${RESET}"
}

# Function to create or update formula
update_formula() {
    echo -e "${CYAN}Updating formula...${RESET}"

    # Get tarball info
    TAR_PATH=$(cat "$BUILD_DIR/tarball_path")
    SHA256=$(cat "$BUILD_DIR/tarball_sha256")

    # Create formula from template
    cat > "$LOCAL_TAP_DIR/$FORMULA_PATH" << EOF
class Rcforge < Formula
  desc "Universal shell configuration system for Bash and Zsh"
  homepage "https://github.com/analog-edge/rcforge"
  url "file://$TAR_PATH"
  sha256 "$SHA256"
  license "MIT"

  depends_on "bash"
  depends_on "zsh" => :recommended

  def install
    # Install main script to prefix
    prefix.install "rcforge.sh"
    prefix.install "include-structure.sh"

    # Install core files
    prefix.install Dir["core/*"]
    prefix.install Dir["utils/*"]

    # Install source files and libraries
    (prefix/"lib").mkpath
    (prefix/"lib").install Dir["lib/*"]

    # Install include files with directory structure
    include_dir = prefix/"include"
    include_dir.mkpath
    include_dir.install Dir["include/*"]

    # Install example scripts
    (prefix/"scripts").mkpath
    (prefix/"scripts").install Dir["scripts/*"]

    # Create exports directory
    (prefix/"exports").mkpath

    # Install documentation
    doc.install Dir["docs/*"]
    doc.install "README.md"
    doc.install "LICENSE"

    # Create executable in bin
    bin.install_symlink prefix/"rcforge.sh" => "rcforge"

    # Make all scripts executable
    system "chmod", "+x", "#{bin}/rcforge"
    system "find", "#{prefix}", "-name", "*.sh", "-exec", "chmod", "+x", "{}", ";"
  end

  def post_install
    # Create configuration directories in user's home
    user_config_dir = "#{ENV["HOME"]}/.config/rcforge"

    # Create directories
    system "mkdir", "-p", "#{user_config_dir}/scripts"
    system "mkdir", "-p", "#{user_config_dir}/include"
    system "mkdir", "-p", "#{user_config_dir}/exports"
    system "mkdir", "-p", "#{user_config_dir}/docs"

    # Copy example files if they don't exist
    if Dir["#{user_config_dir}/scripts/*"].empty?
      system "cp", "-n", "#{prefix}/scripts/README.md", "#{user_config_dir}/scripts/" if File.exist?("#{prefix}/scripts/README.md")
    end

    # Copy documentation files
    system "cp", "-n", "#{doc}/getting-started.md", "#{user_config_dir}/docs/" if File.exist?("#{doc}/getting-started.md")

    # Create a basic README in the user config directory
    readme_path = "#{user_config_dir}/docs/README.md"
    unless File.exist?(readme_path)
      File.open(readme_path, "w") do |file|
        file.write <<~EOS
          # rcForge User Configuration

          This directory contains your personal rcForge shell configuration.

          ## Directory Structure

          - \`scripts/\` - Your shell configuration scripts
          - \`include/\` - Your custom include functions
          - \`exports/\` - Exported configurations for remote servers
          - \`docs/\` - Documentation

          ## Getting Started

          Add your configuration files to the scripts directory following the naming convention:

          ```
          ###_[hostname|global]_[environment]_[description].sh
          ```

          For more information, see the documentation in the docs directory.
        EOS
      end
    end

    # Set correct permissions
    system "chmod", "-R", "u+w", user_config_dir
  end

  def caveats
    <<~EOS
      To complete installation, add the following to your shell configuration file:

      For Bash:
        echo 'source "#{opt_prefix}/rcforge.sh"' >> ~/.bashrc

      For Zsh:
        echo 'source "#{opt_prefix}/rcforge.sh"' >> ~/.zshrc

      Your personal configurations should be added to:
        ~/.config/rcforge/scripts/

      You can run the setup utility to initialize your configuration:
        #{opt_bin}/rcforge --setup

      For more information, see the documentation:
        #{opt_doc}
    EOS
  end

  test do
    # Test 1: Binary exists and is executable
    assert_predicate bin/"rcforge", :exist?
    assert_predicate bin/"rcforge", :executable?

    # Test 2: Core functions can be sourced
    # Use a standalone check to avoid polluting test environment
    system "bash", "-c", "source #{prefix}/core/functions.sh && echo 'Core functions loaded'"

    # Test 3: Create a simple test configuration
    mkdir_p testpath/"scripts"
    (testpath/"scripts/100_test_common_test.sh").write <<~EOS
      #!/bin/bash
      # Test configuration
      export TEST_VARIABLE="Hello, World!"
      echo "Test configuration loaded"
    EOS
    chmod 0755, testpath/"scripts/100_test_common_test.sh"

    # Test 4: Test the include system if Bash version is sufficient
    bash_major_version = \`bash --version | head -1 | awk '{print \$4}' | cut -d. -f1\`.to_i
    if bash_major_version >= 4
      mkdir_p testpath/"include/test"
      (testpath/"include/test/hello.sh").write <<~EOS
        #!/bin/bash
        # Test function
        hello() {
          echo "Hello from include function"
        }
        export -f hello
      EOS
      chmod 0755, testpath/"include/test/hello.sh"

      # Create a test script that loads a function
      (testpath/"test_include.sh").write <<~EOS
        #!/bin/bash
        # Set up test environment
        export RCFORGE_ROOT=#{testpath}
        source #{prefix}/lib/include-functions.sh
        include_function test hello
        hello
      EOS
      chmod 0755, testpath/"test_include.sh"

      # Run the test script
      assert_match "Hello from include function", shell_output("#{testpath}/test_include.sh")
    end

    # Test 5: Test loading configuration
    ENV["RCFORGE_ROOT"] = testpath
    ENV["RCFORGE_SCRIPTS"] = "#{testpath}/scripts"

    # Create a test script that sources rcforge
    (testpath/"test_config.sh").write <<~EOS
      #!/bin/bash
      source #{bin}/rcforge
      echo "TEST_RESULT=\$TEST_VARIABLE"
    EOS
    chmod 0755, testpath/"test_config.sh"

    # Run the test script and check the output
    assert_match "TEST_RESULT=Hello, World!", shell_output("#{testpath}/test_config.sh")
  end
end
EOF

    echo -e "${GREEN}Formula updated: ${YELLOW}$LOCAL_TAP_DIR/$FORMULA_PATH${RESET}"
}

# Function to audit formula
audit_formula() {
    echo -e "${CYAN}Auditing formula...${RESET}"

    # Run brew audit with recommended flags
    # --strict: Run additional checks including RuboCop style checks
    # --new: Run additional checks for new formulae
    # --online: Run additional slower checks that require a network connection
    brew audit --strict --new --online "$TAP_NAME/$FORMULA_NAME" | tee -a "$TEST_LOG" || true

    echo -e "${GREEN}Audit complete. See $TEST_LOG for details.${RESET}"
}

# Function to install formula from local tap
install_formula() {
    echo -e "${CYAN}Installing formula from local tap...${RESET}"

    # Remove previous installation if it exists
    brew uninstall "$TAP_NAME/$FORMULA_NAME" 2>/dev/null || true

    # Install with build-from-source as recommended in the documentation
    # This ensures we're testing the installation process itself, not just the bottle
    HOMEBREW_NO_INSTALL_FROM_API=1 brew install -v --build-from-source "$TAP_NAME/$FORMULA_NAME" | tee -a "$TEST_LOG"

    # If you need to debug installation issues, uncomment this line:
    # HOMEBREW_NO_INSTALL_FROM_API=1 brew install -v --debug --build-from-source "$TAP_NAME/$FORMULA_NAME" | tee -a "$TEST_LOG"

    echo -e "${GREEN}Installation complete!${RESET}"
}

# Function to test formula
test_formula() {
    echo -e "${CYAN}Running tests...${RESET}"

    # Run brew test with verbose flag
    brew test -v "$TAP_NAME/$FORMULA_NAME" | tee -a "$TEST_LOG"

    echo -e "${GREEN}Tests complete!${RESET}"
}

# Main execution
echo -e "${YELLOW}Starting rcForge Homebrew Formula Testing${RESET}"
echo "Log file: $TEST_LOG"
echo "" > "$TEST_LOG"  # Clear log file

# Execute each step
create_tarball
setup_local_tap
update_formula
audit_formula
install_formula
test_formula

echo ""
echo -e "${GREEN}✓ All tests completed!${RESET}"
echo -e "${YELLOW}To uninstall the test formula:${RESET}"
echo "  brew uninstall $TAP_NAME/$FORMULA_NAME"
echo -e "${YELLOW}To remove the test tap:${RESET}"
echo "  brew untap $TAP_NAME"
# EOF