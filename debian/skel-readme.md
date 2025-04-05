# rcForge Skeleton Directory

This directory contains the template configuration files used to initialize a new user's rcForge environment. When a new user is detected during package installation, these files are copied to `~/.config/rcforge/` to provide a starting configuration.

## Directory Structure

- `scripts/` - Example shell configuration scripts
- `docs/` - Documentation files
- `include/` - Empty directory for user include functions
- `exports/` - Empty directory for exported configurations
- `checksums/` - Empty directory for checksum files

## Customization

System administrators can customize the skeleton files to provide organization-specific defaults by modifying the files in this directory.

## File Permissions

When copied to a user's home directory, the installation script:
- Sets directory permissions to 700 (user access only)
- Sets documentation files to 600 (read/write by user)
- Sets shell scripts to 700 (executable by user)

This ensures that user configurations remain private and secure.
