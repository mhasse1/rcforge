# rcForge v0.5.0 Implementation Plan

## 1. Overview

Version 0.5.0 of rcForge introduces a major architectural change to adopt XDG Base Directory Specification compliance, as well as new features for API key management and path configuration. This document outlines the detailed implementation plan to create and deploy these changes.

## 2. Key Changes

1. **XDG-Compliant Directory Structure**
   - Separate user configuration from system files
   - Move configuration to `~/.config/rcforge/`
   - Move system files to `~/.local/rcforge/`

2. **API Key Management**
   - New `apikey` utility
   - Secure storage for API keys
   - Automatic environment variable export

3. **Path Configuration**
   - File-based path configuration
   - Early PATH setup
   - Structured format with comments

4. **Documentation Improvements**
   - Remove example scripts (move to wiki)
   - Update Style Guide to v0.5.0
   - Create migration guide for users

## 3. Implementation Tasks

### Phase 1: Core Structure Development

1. **Create Directory Structure**
   - Define the new XDG-compliant directory structure
   - Create folder structure templates for installer

2. **Update Environment Variables**
   - Define new environment variables in `rcforge.sh`:
     - `RCFORGE_CONFIG_ROOT` for ~/.config/rcforge
     - `RCFORGE_LOCAL_ROOT` for ~/.local/rcforge
     - Update all related path variables

3. **Create Configuration Files**
   - Add `path.conf` for PATH configuration
   - Add `api_key_settings` template

### Phase 2: Core Script Updates

1. **Update rcforge.sh**
   - Modify paths to match new structure
   - Add path configuration processing
   - Add API key processing
   - Update execution model

2. **Update FindRcScripts function**
   - Modify to support new directory structure
   - Maintain backward compatibility
   - Update path detection logic

3. **Update Shell RC File Integration**
   - Modify sourcing line to point to new location
   - Handle migration from old to new paths

### Phase 3: New Feature Implementation

1. **Implement API Key Management Utility**
   - Create `apikey.sh` utility
   - Implement key storage functionality
   - Implement commands: set, list, remove, show
   - Add verification and security checks

2. **Implement Path Configuration**
   - Create path configuration processor
   - Add default path configuration
   - Document customization options

### Phase 4: Upgrade & Migration Logic

1. **Create Migration Logic in Installer**
   - Detect pre-0.5.0 installations
   - Create backup before migration
   - Move files to correct locations
   - Update shell RC files

2. **Update Backup/Restore Functionality**
   - Enhance backup to include both directories
   - Update restore to handle new structure

3. **Update Integrity Checks**
   - Update checks to verify both directories
   - Add checks for new configuration files

### Phase 5: Documentation and Testing

1. **Update Documentation**
   - Create migration guide
   - Update style guide to v0.5.0
   - Create or update path configuration docs
   - Create API key management docs

2. **Create Test Cases**
   - Test fresh installation
   - Test migration from pre-0.5.0
   - Test API key management
   - Test path configuration

## 4. Detailed Implementation Steps

### Step 1: Updated Directory Structure

Create the following structure:

```
~/.config/rcforge/          # User configuration
├── config/                 # Configuration files
│   └── path.conf           # PATH configuration
└── rc-scripts/             # Shell configuration scripts

~/.local/rcforge/           # System files
├── backups/                # Backup files
├── config/                 # System configuration
│   ├── api_key_settings    # API key storage
│   ├── bash-location       # Compliant Bash path
│   └── checksums/          # File checksums
├── rcforge.sh              # Main loader script
└── system/                 # System components
    ├── core/               # Core functionality
    ├── lib/                # Shared libraries
    └── utils/              # System utilities
```

### Step 2: Update `rcforge.sh`

Update `rcforge.sh` to support the new structure:
- Add XDG environment variables
- Add path configuration processing
- Add API key processing
- Update script sourcing logic
- Maintain backward compatibility

### Step 3: Implement `apikey.sh` Utility

Create a new utility for API key management:
- Follow the template from `template-utility.sh`
- Implement commands for managing API keys
- Ensure proper permission handling
- Add comprehensive help and examples

### Step 4: Update `install-script.sh`

Enhance the installer to support migration:
- Add detection for pre-0.5.0 installations
- Add migration confirmation prompt
- Add backup creation
- Add file relocation logic
- Add shell RC file updating

### Step 5: Update Documentation

Update documentation:
- Update style guide to v0.5.0
- Create migration guide
- Update user documentation

### Step 6: Testing

Thoroughly test all aspects:
- Fresh installation
- Migration from pre-0.5.0
- API key management
- Path configuration
- Shell RC file updating

## 5. Manifest File Update

Update `file-manifest.txt` to include the new structure and files:
- Update directory structure section
- Add new files (apikey.sh, etc.)
- Update paths for relocated files

## 6. Migration Process for Users

The migration process for existing users will be:

1. Run the installer
2. Confirm the migration
3. Wait for backup and migration
4. Test the new installation
5. Update shell RC files if necessary

## 7. Timeline

1. **Week 1**: Core structure and script updates
2. **Week 2**: New feature implementation
3. **Week 3**: Upgrade and migration logic
4. **Week 4**: Documentation and testing
5. **Week 5**: Release preparation and final testing

## 8. Deliverables

1. Updated core files:
   - `rcforge.sh`
   - `utility-functions.sh` (FindRcScripts updates)
   - `install-script.sh`

2. New files:
   - `apikey.sh`
   - `path.conf` template
   - `api_key_settings` template

3. Updated documentation:
   - `style-guide-050.md`
   - Migration guide
   - User documentation

## 9. Future Considerations

1. **Syncing Functionality**: Enhance syncing between machines now that configuration is separated
2. **Additional Configuration**: Consider more user-facing configuration options in `~/.config/rcforge/config/`
3. **Plugin System**: Consider a more formal plugin architecture leveraging the new structure
4. **Installer Improvement**: Enhance installer with more interactive options

## 10. Conclusion

The v0.5.0 update represents a significant architectural improvement for rcForge. The implementation plan outlined above provides a structured approach to creating and deploying these changes while ensuring backward compatibility and a smooth migration experience for users.

# EOF