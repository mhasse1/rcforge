# rcForge v0.2.0 Documentation Summary

## Key Documents to Preserve Whole
- `/docs/STYLE_GUIDE.md`: Coding and project style standards
- `/docs/rcforge-ai-dev-standards.md`: AI-assisted development guidelines
- `/docs/FILE_STRUCTURE_GUIDE.md`: Detailed file structure documentation

The primary focus of this document is to capture previous design, user, and developer documentation to reduce the overhead when interacting with Claude.  

**CRITICAL!** These are previous standards in case we need to refer back to them. They are not the current standards.

**CRITICAL!** The initial 0.3.0 redisign is documented in {project-root}/rcforge-redesign-v0.3.0.md

## Core Design Principles

### Simplification Goals

1. **Reduce Complexity**
   - Simplify the include system
   - Minimize function libraries
   - Create a more intuitive user experience

2. **Modular Design**
   - Maintain cross-shell compatibility
   - Support machine-specific configurations
   - Provide clear, deterministic loading order

### Core Functionality Requirements
- Support Bash 4.0+ and Zsh 5.0+
- Maintain existing key features:
  - Hostname-based configuration
  - Sequence-based loading
  - Conflict detection
  - Checksum verification
  - Secure configuration management

## Configuration Structure

### Naming Convention
```
###_[hostname|global]_[environment]_[description].sh
```

### Sequence Number Ranges
| Range | Purpose |
|-------|---------|
| 000-099 | Critical global configurations |
| 100-299 | Common configurations |
| 300-499 | Bash-specific configurations |
| 500-699 | Zsh-specific configurations |
| 700-899 | Hostname-specific common configs |
| 900-949 | Hostname-specific Bash configs |
| 950-999 | Hostname-specific Zsh configs |

## Security Considerations

### Core Security Principles
1. **Prevent Root Execution**
   - Explicitly block root-level configuration
   - Provide emergency override mechanism
   - Protect sensitive configuration data

2. **File Permission Model**
   - 700 for directories
   - 700 for executable scripts
   - 600 for configuration files
   - Use restrictive `umask 077`

### Security Features to Maintain
- Root permission checks
- Secure file permissions
- Checksum verification
- Secure export functionality

## Utility and Include System Redesign

### Current Challenges
- Overly complex include system
- Extensive function libraries
- Difficult maintenance

### Proposed Improvements
1. **Utility Access Options**
   - Utilities folder added to PATH
   - Core `rc` command with built-in utilities
   - Potential hybrid approach

2. **Include System Simplification**
   - Minimal core function sourcing
   - Streamlined dependency management
   - Easier function override mechanism

### Proposed Utility Categories
- Path management
- Common utilities
- Git integration
- Network tools
- System information
- Development helpers

## Installation and Deployment

### Support Multiple Installation Methods
- Git clone
- Package managers (Debian, Homebrew)
- Manual installation
- Development mode

### Deployment Paths
- User configuration: `~/.config/rcforge/`
- System installation:
  - Linux/Debian: `/usr/share/rcforge/`
  - Homebrew: `$(brew --prefix)/share/rcforge/`
  - MacPorts: `/opt/local/share/rcforge/`

## Migration Considerations

### User Experience Priorities
- Preserve existing configuration structure
- Maintain sequence-based loading
- Minimize required changes to user scripts
- Provide clear migration guides

## Open Questions and Exploration

1. Long-term evolution of include system
2. Potential `rc` command framework enhancements
3. Community-driven utility ecosystem
4. Balancing flexibility with simplicity

## Continuous Improvement Strategy

- Prioritize readability and maintainability
- Reduce system dependencies
- Create more intuitive user experience
- Maintain cross-platform compatibility
- Provide comprehensive documentation

## Recommended Next Steps

1. Refactor include system
2. Simplify utility access
3. Enhance security model
4. Create migration tools
5. Update documentation
6. Develop comprehensive test suite

### Key Refactoring Targets
- Include system architecture
- Utility script complexity
- Function library consolidation
- Loading mechanism
- User configuration experience

## Performance and Usability Goals

- Minimize shell startup overhead
- Provide clear, actionable error messages
- Support easy configuration and customization
- Maintain backward compatibility
- Optimize for different shell environments
