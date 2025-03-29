# rcForge Folder Structures

## Development and Installation Overview

1. For development, users work with the GitHub repository structure in their preferred development directory
2. User installation configuration remains in `~/.config/rcforge/`

## Deployment Folder Structures

User deployment will be to `~/.config/rcforge`
System deployment will follow the appropriate folders based on the packaging system and operating system standards.

### Examples of Different Package Management Systems

#### Linux/Debian Packages
- Files in `/usr/share/rcforge/`
- Configuration in `/etc/rcforge/`
- Executables in `/usr/bin/`

#### Homebrew (macOS)
- Install to Homebrew prefix: `$(brew --prefix)/share/rcforge/`
- Executables symlinked to `$(brew --prefix)/bin/`
- User config remains in `~/.config/rcforge/`

#### MacPorts
- Similar to Homebrew, but files in `/opt/local/share/rcforge/`

## Typical Deployment Structures

### System-Level Structure (Linux)
```
/usr/share/rcforge/           # System-level files
  ├── core/                   # Core functionality
  ├── utils/                  # Utility scripts
  ├── src/                    # Source code
  │   └── lib/                # Libraries
  ├── include/                # System include functions
  └── rcforge.sh              # Main loader script
```

### User-Level Structure
```
~/.config/rcforge/            # User installation
  ├── scripts/                # User shell configuration scripts
  ├── include/                # User custom include functions
  ├── exports/                # Exported configurations for remote servers
  ├── docs/                   # Documentation
  └── rcforge.sh              # Main loader script (copied from system or repo)
```

## Development Folder Structure

### Project Repository Structure
```
<PROJECT_ROOT>                # Generic project root directory
├── CHANGELOG.md
├── Formula
│   └── rcforge.rb            # Homebrew formula definition
├── LICENSE
├── Makefile
├── README.md
├── checksums
├── core/                     # Core shell scripts
├── debian/                   # Debian packaging files
├── docs/                     # Project documentation
├── exports/
├── include/
├── packaging/                # Packaging-related scripts and configurations
│   ├── INSTALL.md
│   ├── homebrew/
│   └── scripts/
│       ├── brew-test-local.sh
│       ├── build-deb.sh
│       └── test-deb.sh
├── rcforge.sh                # Main project script
├── res/                      # Resource files (logos, etc.)
├── scripts/                  # Shell configuration scripts
├── src/
│   └── lib/
├── tmp/
└── utils/                    # Utility scripts
```

### Notes for Developers

- `<PROJECT_ROOT>` is a placeholder for your local project directory
- Common locations might include:
  - macOS/Linux: `~/src/rcforge`, `~/Projects/rcforge`
  - Windows: `C:\Users\<username>\source\repos\rcforge`
- Replace `<PROJECT_ROOT>` with the actual path to your local repository

### Download Folder

When downloading code or documentation, consider using a consistent download location:
- Suggested: `~/Downloads` or `~/src/downloads` (flat structure)

## Repository Details

- Repository URL: https://github.com/mhasse1/rcforge.git
- Total directories: 22
- Total files: 64

## Best Practices

1. Maintain consistent folder structure across different development environments
2. Keep user configurations separate from system-level installations
3. Use platform-specific conventions for package management
4. Document any significant deviations from the standard structure
