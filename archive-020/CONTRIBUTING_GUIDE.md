# Contributing to rcForge

First off, thank you for considering contributing to rcForge! It's people like you that make rcForge such a great tool for shell environment management across multiple machines.

This document provides guidelines and information for contributing to rcForge. By following these guidelines, you help maintain consistency and quality throughout the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Project Overview](#project-overview)
- [Development Environment Setup](#development-environment-setup)
- [Project Structure](#project-structure)
- [Coding Standards](#coding-standards)
- [Pull Request Process](#pull-request-process)
- [Testing Guidelines](#testing-guidelines)
- [Documentation Requirements](#documentation-requirements)
- [Release Process](#release-process)

## Code of Conduct

Please note that this project adheres to a Contributor Code of Conduct. By participating in this project, you agree to abide by its terms.

## Project Overview

rcForge is a flexible, modular configuration system for Bash and Zsh shells that provides a unified framework for managing shell environments across multiple machines.

Key features include:
- Cross-shell compatibility with Bash and Zsh
- Machine-specific configurations based on hostname
- Deterministic loading order with explicit sequence numbers
- Conflict detection and resolution
- Version control friendliness
- Visual configuration diagrams
- Modular include system for function organization

## Development Environment Setup

### System Requirements

- **Bash 4.0+** (required for the include system and associative arrays)
- Zsh 5.0+ (for testing Zsh compatibility)
- Git
- Standard UNIX utilities (find, sort, etc.)
- `md5sum` or equivalent

### Setting Up Development Environment

1. **Clone the repository to the development location**:
   ```bash
   git clone https://github.com/mhasse1/rcforge.git ~/src/rcforge
   ```

2. **Set development mode to use the repo directly**:
   ```bash
   export RCFORGE_DEV=1
   source ~/src/rcforge/rcforge.sh
   ```

3. **Install development dependencies**:
   - For Debian packaging: `sudo apt install devscripts debhelper dh-make`
   - For macOS/Homebrew: Install Homebrew if not already installed

### Development Workflow

1. Fork the repository on GitHub
2. Create a new branch for your feature or bugfix
3. Make your changes
4. Test your changes thoroughly (see [Testing Guidelines](#testing-guidelines))
5. Submit a pull request

## Project Structure

rcForge follows a specific folder structure for development and deployment:

### Development Repository Structure

```
~/src/rcforge/                # Development repository
  ├── CHANGELOG.md
  ├── Formula/                # Homebrew formula
  │   └── rcforge.rb
  ├── LICENSE
  ├── Makefile
  ├── README.md
  ├── core/                   # Core shell scripts
  ├── debian/                 # Debian packaging files
  ├── docs/                   # Project documentation
  ├── include/                # Include system functions
  ├── packaging/              # Packaging scripts
  │   ├── INSTALL.md
  │   ├── homebrew/
  │   └── scripts/
  ├── rcforge.sh              # Main project script
  ├── scripts/                # Example shell configurations
  ├── src/                    # Source code
  │   └── lib/
  └── utils/                  # Utility scripts
```

### Deployment Folder Structures

rcForge has three main deployment paths:

1. **User Configuration**:
   ```
   ~/.config/rcforge/
     ├── scripts/             # User shell configurations
     ├── include/             # User custom include functions
     ├── exports/             # Exported configurations for remote servers
     ├── docs/                # Documentation
     └── rcforge.sh           # Main loader script
   ```

2. **Linux/Debian System Installation**:
   ```
   /usr/share/rcforge/
     ├── core/                # Core functionality
     ├── utils/               # Utility scripts
     ├── src/                 # Source code
     │   └── lib/             # Libraries
     ├── include/             # System include functions
     └── rcforge.sh           # Main loader script
   ```

3. **Homebrew System Installation (macOS)**:
   ```
   $(brew --prefix)/share/rcforge/
     ├── core/                # Core functionality
     ├── utils/               # Utility scripts
     ├── src/                 # Source code
     │   └── lib/             # Libraries
     ├── include/             # System include functions
     └── rcforge.sh           # Main loader script
   ```

## Coding Standards

### Shell Scripts

1. **Naming Convention**: All scripts follow this naming pattern:
   ```
   ###_[hostname|global]_[environment]_[description].sh
   ```
   Where:
   - `###`: Three-digit sequence number controlling load order
   - `[hostname|global]`: Either the hostname of a specific machine or "global" for all machines
   - `[environment]`: One of "common", "bash", or "zsh"
   - `[description]`: Brief description of the configuration purpose

2. **Sequence Number Standards**:
   | Range | Purpose |
   |-------|---------|
   | 000-199 | Critical configurations (PATH, etc.) |
   | 200-399 | General configurations (Environment, Prompt, etc.) |
   | 400-599 | Functions and aliases |
   | 600-799 | Package specific configurations (pyenv, homebrew, etc.) |
   | 800-949 | End of script info displays, clean up and closeout |
   | 950-999 | Critical end of RC scripts |

3. **Script Structure**:
   ```bash
   #!/bin/bash
   # Brief description of what this script does
   # Author: Your Name
   # Date: YYYY-MM-DD

   # Include required functions
   include_function common is_macos
   include_function path add_to_path

   # Local function definitions (if needed)
   local_function() {
     # Function code here
   }

   # Main configuration code
   # ...

   # Debug information
   debug_echo "Configured something: $variable"
   ```

4. **Error Handling**:
   - Use appropriate error handling techniques
   - Check for command existence with `cmd_exists`
   - Validate inputs
   - Use conditional returns with meaningful status codes

5. **Comments and Documentation**:
   - Document non-obvious code sections
   - Add headers to all files
   - Document function parameters and return values
   - Use meaningful variable and function names

### Shell Style Guide

1. **Variable Naming**:
   - Use lowercase for variable names
   - Use underscores to separate words
   - Use uppercase for constants or environment variables

2. **Indentation**:
   - Use 2 spaces for indentation
   - Don't use tabs

3. **Quoting**:
   - Quote all variable expansions: `"$variable"`
   - Use `[[` and `]]` for test commands
   - Use `$()` for command substitution, not backticks

4. **Function Structure**:
   - Use `local` for function variables
   - Document each function's purpose and parameters
   - Return meaningful status codes
   - Export functions that should be available to other scripts

## Pull Request Process

1. **Branch Naming**:
   - Use descriptive names for branches
   - Prefix with type of change: `feature/`, `bugfix/`, `docs/`, etc.

2. **Commit Messages**:
   - Write clear, concise commit messages
   - Use present tense ("Add feature" not "Added feature")
   - Reference issue numbers in commit messages

3. **Pull Request Template**:
   - Provide a clear description of the changes
   - Link to any relevant issues
   - List any dependencies or requirements
   - Describe how to test the changes

4. **Review Process**:
   - PRs require at least one code review
   - Address all review comments
   - Maintain a respectful and collaborative approach to feedback

5. **Merge Requirements**:
   - All tests must pass
   - Documentation must be updated
   - Code must follow style guidelines
   - Conflicts must be resolved

## Testing Guidelines

### Unit Testing

1. **Shell Script Testing**:
   - Test your scripts with both Bash 4.0+ and Zsh
   - Test with different operating systems if possible
   - Use `SHELL_DEBUG=1` to validate behavior

2. **Function Testing**:
   - Test include system functions individually
   - Verify function return values and side effects
   - Test edge cases and error conditions

### Integration Testing

1. **Package Testing**:
   - Test Debian package installation with the provided scripts
   - Test Homebrew formula installation
   - Verify system-level functionality after installation

2. **Conflict Testing**:
   - Use `check-seq.sh` to validate there are no sequence conflicts
   - Test with various hostnames and shell configurations

### Automated Testing

1. **CI/CD**:
   - GitHub Actions workflows are provided for linting and testing
   - Fix any issues reported by the CI system before merging

2. **Testing Scripts**:
   - Use the `test-deb.sh` script for testing Debian packages
   - Use the `brew-test-local.sh` script for testing Homebrew formulas

## Documentation Requirements

### Code Documentation

1. **Inline Comments**:
   - Document complex logic
   - Explain non-obvious choices
   - Document any workarounds or hacks

2. **Function Documentation**:
   - Document parameters and return values
   - Explain side effects
   - Provide usage examples for complex functions

### User Documentation

1. **User Guides**:
   - Update relevant user guides
   - Document new features
   - Provide examples for configuration
   - Explain any breaking changes

2. **README Updates**:
   - Update feature lists
   - Update version numbers
   - Keep installation instructions current

### Diagrams and Visual Aids

1. **Loading Order Diagrams**:
   - Generate updated diagrams with the `diagram-config.sh` script
   - Include in documentation for complex features

## Release Process

1. **Version Numbering**:
   - Follow semantic versioning (MAJOR.MINOR.PATCH)
   - Document all changes in CHANGELOG.md

2. **Package Building**:
   - Update version in Makefile, Debian control, and Homebrew formula
   - Build packages with the provided scripts
   - Test packages thoroughly before release

3. **Release Steps**:
   - Tag the release in Git
   - Build all packages
   - Create a GitHub release
   - Upload packages to the release
   - Update formula in the Homebrew tap

## Getting Help

If you need help or have questions about contributing, you can:
- Open an issue on GitHub
- Reach out to the maintainers
- Check the documentation for more information

Thank you for contributing to rcForge!
# EOF
