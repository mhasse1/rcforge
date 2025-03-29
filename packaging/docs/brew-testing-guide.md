# Homebrew Formula Testing Guide for rcForge

This guide will help you test and improve your rcForge Homebrew formula based on Homebrew best practices.

## Project Structure Reference

The project follows a specific folder structure:

```
/Users/mark/src/rcforge
├── Formula
│   └── rcforge.rb      # Homebrew formula definition
├── packaging
│   ├── homebrew
│   └── scripts
│       └── brew-test-local.sh  # Local testing script
└── (other project directories)
```

## Current Formula vs. Recommended Approach

After reviewing the Homebrew Formula Cookbook and best practices, here are the key improvements that could be made to your current approach:

### 1. Test Block Improvements

**Current Approach**:
- Minimal testing that primarily checks if the binary exists
- No testing of actual functionality

**Recommended Approach**:
- Test that the binary exists and runs correctly
- Test that core functions can be sourced
- Test configuration file loading
- Test the include system functionality
- Use `assert_match` to verify output content

### 2. Local Testing Workflow

**Current Approach**:
- Using temporary files for URL and SHA, which is creative but non-standard
- Testing directly against the formula without a dedicated test tap
- Manual steps that can be error-prone

**Recommended Approach**:
- Create a proper local tap for testing
- Generate a proper tarball with the correct structure
- Use Homebrew's built-in audit and test commands
- Automate the testing workflow with a script

### 3. Formula Structure

**Current Approach**:
- Basic formula structure with limited instructions
- No post-install steps
- Limited installation logic
- No directory structure creation

**Recommended Approach**:
- Include comprehensive installation steps
- Add post-install hooks to create necessary directories
- Add caveats to guide users on post-installation setup
- Use `opt_bin` and other Homebrew conventions for paths

## Steps for Testing Your Homebrew Formula

### 1. Set Up Development Environment

```bash
# Make sure you have the latest Homebrew
brew update

# Set environment variable to use local repos instead of API
export HOMEBREW_NO_INSTALL_FROM_API=1
```

### 2. Use the Test Script

The provided `brew-test-local.sh` script (located in `packaging/scripts/`) automates most of the testing process:

```bash
# Navigate to the script directory
cd ~/src/rcforge/packaging/scripts

# Make the script executable
chmod +x brew-test-local.sh

# Run the test script
./brew-test-local.sh
```

This script will:
1. Create a tarball of your project
2. Calculate the SHA256 for verification
3. Create a local tap for testing
4. Generate a formula file in the tap
5. Run `brew audit --strict --new --online` to check for formula issues
   - `--strict`: Runs additional style checks
   - `--new`: Runs additional checks for new formulae
   - `--online`: Runs additional slower checks that require network connection
6. Install the formula from source using `--build-from-source`
7. Run the test block with `brew test` to verify functionality

### 3. Manual Testing Steps

After running the script, you can perform additional manual testing:

```bash
# Ensure the formula installs without errors
brew install analog-edge/homebrew-rcforge/rcforge

# Run the tests manually to see detailed output
brew test -v analog-edge/homebrew-rcforge/rcforge

# Use the installed software
rcforge --version

# Try sourcing the script in a new shell
bash -c 'source "$(brew --prefix)/bin/rcforge"'
```

### 4. Debugging Formula Issues

If you encounter issues, you can:

```bash
# Install with debugging enabled
brew install -v --debug analog-edge/homebrew-rcforge/rcforge

# Edit the formula directly
vim "$(brew --repository)/Library/Taps/analog-edge/homebrew-rcforge/Formula/rcforge.rb"

# Uninstall and reinstall to test changes
brew uninstall analog-edge/homebrew-rcforge/rcforge
brew install analog-edge/homebrew-rcforge/rcforge
```

### 5. Deployment Considerations

For Homebrew (macOS), the installation will follow these conventions:
- System files: `$(brew --prefix)/share/rcforge/`
- Executables: Symlinked to `$(brew --prefix)/bin/`
- User configuration: Remains in `~/.config/rcforge/`

### 6. Preparing for Publication

Once your formula is working locally:

1. Create a proper GitHub release with a tagged version
2. Update the formula to use the GitHub release URL instead of a local file
3. Calculate the SHA256 of the release tarball
4. Update the formula with the correct SHA256
5. Create a GitHub repository for your tap (named `homebrew-rcforge`)
6. Push the formula to that repository

## What Makes a Good Homebrew Test

According to the [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook#add-a-test-to-the-formula), good tests should:

1. Not require user input
2. Test basic functionality instead of just using `--version` or `--help`
   - The documentation specifically notes that `foo --version` and `foo --help` are considered bad tests
   - Good tests demonstrate actual functionality (e.g., `foo build-foo input.foo`)
3. Use `testpath` for creating testing directories
   - The test block automatically creates and changes to a temporary directory
   - The environment variable HOME is set to testpath within the test block
4. Use assertions to verify results (`assert_predicate`, `assert_match`, etc.)
5. Be repeatable and reliable
6. Create any necessary input files or test environment

## Conclusion

By following these guidelines and using the provided testing script and improved formula, you should be able to properly test your Homebrew formula before publishing it. This approach follows Homebrew's best practices and will help ensure that your formula works reliably for users.

Remember to keep your formula, test block, and SHA256 values up to date with each new release of rcForge.
