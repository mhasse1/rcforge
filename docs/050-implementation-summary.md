# rcForge v0.5.0 Implementation Plan

## Overview

Version 0.5.0 of rcForge introduces significant architectural changes to better align with XDG standards, provide cleaner separation between user configuration and system files, and add important new features like API key management and improved path handling.

## Key Changes

### 1. XDG-Compliant Directory Structure

The directory structure has been redesigned to separate user configuration from system files:

**Before (v0.4.x):**
```
~/.config/rcforge/
├── backups/
├── docs/
├── rc-scripts/
├── rcforge.sh
└── system/
    ├── core/
    ├── lib/
    └── utils/
```

**After (v0.5.0):**
```
~/.config/rcforge/          # User configuration
├── config/
│   └── path.conf
└── rc-scripts/

~/.local/rcforge/           # System files
├── backups/
├── config/
│   ├── api_key_settings
│   ├── bash-location
│   └── checksums/
├── rcforge.sh
└── system/
    ├── core/
    ├── lib/
    └── utils/
```

### 2. New Features

1. **API Key Management**
   - Store and manage API keys securely
   - Keys automatically exported as environment variables
   - New `rc apikey` command for key management

2. **Improved Path Management**
   - Configured via text file rather than hardcoded paths
   - More flexible and user-customizable
   - Applied early in startup process

3. **Removed Example Scripts**
   - Removed example scripts from installation
   - Documentation moved to wiki for better maintainability

### 3. Migration Process

The installer script has been enhanced to:
1. Detect existing pre-0.5.0 installations
2. Create a backup before migration
3. Move files to appropriate locations in the new structure
4. Update shell RC files to reference the new rcforge.sh location
5. Create initial configuration files for new features

## Implementation Files

We've created or modified these key files:

1. **install-script.sh**
   - Enhanced to handle migration from pre-0.5.0 to 0.5.0
   - Supports the new directory structure
   - Includes confirmation prompt for migration

2. **rcforge.sh**
   - Updated with new XDG paths
   - Added path.conf processing
   - Added API key processing
   - Adjusted core loading logic

3. **utility-functions.sh (FindRcScripts function)**
   - Updated to support the new directory structure
   - Maintains backward compatibility with pre-0.5.0

4. **apikey.sh**
   - New utility for API key management
   - Supports setting, listing, removing and showing keys
   - Secure storage of sensitive information

## Deployment Steps

1. Update the manifest file to include new files and updated paths
2. Test the migration from a pre-0.5.0 installation
3. Test a fresh installation of 0.5.0
4. Verify the API key management functionality
5. Update documentation to reflect the new structure and features
6. Tag and release v0.5.0

## Testing Checklist

- [ ] Fresh installation of v0.5.0
- [ ] Migration from v0.4.x to v0.5.0
- [ ] Path configuration loading
- [ ] API key management commands
- [ ] RC scripts loading in new location
- [ ] Shell RC file updating
- [ ] Backup and recovery functionality
- [ ] Error handling during installation/migration

## Future Considerations

1. Consider adding more specialized configuration options in `~/.config/rcforge/config/`
2. Enhance syncing capabilities between machines
3. Add more user-friendly customization tools
4. Improve documentation with more examples of the new structure

## Conclusion

The v0.5.0 update represents a significant architectural improvement that will make rcForge more maintainable, customizable, and aligned with standard practices. The migration process has been designed to be as seamless as possible while preserving user customizations.