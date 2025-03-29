# rcForge Package Installation Guide

This guide explains how to build and install rcForge using Debian packages or Homebrew formulas.

## Prerequisites

### Common Requirements
- Git repository with rcForge code
- Bash 4.0 or newer

### For Debian Package Building
- `debhelper`, `devscripts`, and `dh-make` packages
- Basic knowledge of Debian packaging

### For Homebrew Formula
- Homebrew installed (on macOS)
- Ruby knowledge (basic)

## Building the Debian Package

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/rcforge.git
   cd rcforge
   ```

2. **Setup Build Environment**
   ```bash
   sudo apt update
   sudo apt install devscripts debhelper dh-make
   ```

3. **Run the Build Script**
   ```bash
   ./build-deb.sh 2.0.0
   ```
   This will:
   - Create a temporary build directory
   - Copy all necessary files
   - Set up Debian packaging configuration
   - Build the .deb package
   - Move the package to your repository directory

4. **Install the Package**
   ```bash
   sudo dpkg -i rcforge_2.0.0_all.deb
   sudo apt install -f  # Resolve any dependencies
   ```

## Creating a Homebrew Formula

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/rcforge.git
   cd rcforge
   ```

2. **Run the Homebrew Formula Script**
   ```bash
   ./create-homebrew.sh 2.0.0
   ```
   This will:
   - Create a source tarball
   - Calculate its SHA256 hash
   - Generate the Homebrew formula
   - Optionally test the installation

3. **Creating a Homebrew Tap**
   ```bash
   # Create a new GitHub repository named homebrew-rcforge
   mkdir -p homebrew-rcforge/Formula
   cp rcforge.rb homebrew-rcforge/Formula/
   cd homebrew-rcforge
   git init
   git add Formula/rcforge.rb
   git commit -m "Add rcforge formula"
   git remote add origin https://github.com/yourusername/homebrew-rcforge.git
   git push -u origin main
   ```

4. **Installing from the Tap**
   ```bash
   brew tap yourusername/rcforge
   brew install rcforge
   ```

## Testing the Packages

### Testing the Debian Package
```bash
# Install the package
sudo dpkg -i rcforge_2.0.0_all.deb
sudo apt install -f

# Verify installation
ls -l /usr/share/rcforge/

# Test rcforge command
rcforge --help

# Check if rcforge.sh is properly installed
cat /usr/share/rcforge/rcforge.sh
```

### Testing the Homebrew Formula
```bash
# Install from the formula file
brew install --formula ./rcforge.rb

# Verify installation
ls -l $(brew --prefix)/share/rcforge/

# Test rcforge command
rcforge --help
```

## Making Packages Available

### Debian Package Distribution
1. **Set up a Personal Package Archive (PPA) on Launchpad**
   - Create an account on Launchpad
   - Set up a PPA
   - Upload your package

2. **Create a Repository on GitHub**
   - Host the .deb file in GitHub Releases
   - Users can download and install manually

### Homebrew Formula Distribution
1. **Create a Homebrew Tap**
   - Use the GitHub repository created earlier (homebrew-rcforge)
   - Users can install with `brew tap yourusername/rcforge`
   - Then `brew install rcforge`

2. **Submit to Homebrew Core**
   - For wider distribution, you can submit your formula to Homebrew Core
   - Fork the homebrew-core repository
   - Add your formula to the Formula/r/ directory
   - Submit a pull request with comprehensive testing

## Post-Installation Configuration

After installing rcForge via either method, users need to:

1. **Source rcForge in Shell Configuration**
   ```bash
   # For Bash users
   echo 'source "/usr/share/rcforge/rcforge.sh"' >> ~/.bashrc
   
   # For Zsh users  
   echo 'source "/usr/share/rcforge/rcforge.sh"' >> ~/.zshrc
   ```

2. **Create Custom Configurations**
   ```bash
   # Run the setup script
   rcforge
   ```
   This will:
   - Create the user configuration directories
   - Set up default configurations
   - Explain how to customize rcForge

3. **Test the Installation**
   ```bash
   # Start a new shell or reload configuration
   source ~/.bashrc  # or ~/.zshrc
   
   # List available include functions
   include_function -h
   ```

## Troubleshooting

### Common Issues with Debian Packages

1. **Package Dependencies**
   If you encounter dependency issues:
   ```bash
   sudo apt install -f
   ```

2. **Bash Version Too Old**
   The package requires Bash 4.0+. On older systems:
   ```bash
   # Check Bash version
   bash --version
   
   # Install newer Bash
   sudo apt install bash
   ```

3. **Permission Issues**
   If scripts aren't executable:
   ```bash
   sudo chmod +x /usr/share/rcforge/*.sh
   sudo chmod +x /usr/bin/rcforge
   ```

### Common Issues with Homebrew

1. **Formula Audit Warnings**
   When submitting to Homebrew Core, run:
   ```bash
   brew audit --strict --online rcforge
   ```
   Fix any issues before submission.

2. **Version Conflicts**
   If you have multiple versions:
   ```bash
   brew unlink rcforge
   brew link rcforge
   ```

3. **Bash Version Issues on macOS**
   ```bash
   # Verify Homebrew Bash is installed
   brew info bash
   
   # Make Homebrew Bash your default shell
   echo $(brew --prefix)/bin/bash | sudo tee -a /etc/shells
   chsh -s $(brew --prefix)/bin/bash
   ```

## Package Maintenance

### Updating the Debian Package

1. Update version number in the control file
2. Update changelog
3. Run the build script with the new version
4. Test the new package
5. Upload to your distribution channel

### Updating the Homebrew Formula

1. Update the version and SHA256 in the formula
2. Test the updated formula
3. Commit and push changes to your tap
4. If in Homebrew Core, submit a PR with the changes

## Testing Strategy

For comprehensive testing across environments:

1. **Create Test VM/Containers**
   - Debian/Ubuntu for .deb packages
   - macOS for Homebrew formulas

2. **Automated Testing**
   - Use Docker for Debian/Ubuntu testing
   - Use GitHub Actions for macOS testing
   - Test against multiple versions of Bash and Zsh

3. **Integration Testing**
   - Test that rcForge correctly loads user configurations
   - Test with various shell configurations
   - Test upgrade scenarios
