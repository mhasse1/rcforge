# rcForge Project Instructions (v0.3.0)

## Project Information
- **Name**: rcForge
- **Version**: 0.3.0 (redesign in progress)
- **Structure**: User-centric design with installation in `~/.config/rcforge/`

## Technical Requirements
- **Core System**: Implemented in Bash 4.0 or higher
  - All shebangs use `#!/usr/bin/env bash` for cross-platform compatibility
  - macOS users will need to install modern Bash via Homebrew or MacPorts
- **End User Support**:
  - Both Bash and Zsh are supported as equal first-class citizens
  - Configuration scripts can be shell-specific or common to both
  - System adapts to user's active shell environment

## Key Process Guidelines

### File Location & Modification
- Verify file locations using uploaded documents and `~/.config/rcforge/docs/FILE_STRUCTURE_GUIDE.md`
- Always specify complete file paths when suggesting changes
- Never suggest structural changes without explicit discussion
- End all generated files with `# EOF` comment to verify completeness

### Development Approach
- Discuss design options before coding
- Evaluate tradeoffs between potential solutions
- Request permission before generating files
- Confirm complete generation of all files
- Focus on simplicity - avoid overengineering

## Code Standards

### RC Scripts Development
- Follow naming convention: `###_[hostname|global]_[environment]_[description].sh`
- Place all RC scripts in `~/.config/rcforge/rc-scripts/`
- Ensure shell-specific scripts use appropriate syntax for their target shell
- Use "common" scripts for functionality that works in both shells

### RC Command Utilities
- Place system utilities in `~/.config/rcforge/system/utils/`
- Place user utilities in `~/.config/rcforge/utils/`
- Support both `help` and `summary` subcommands
- Design with user overrides in mind
- Core utilities must work in both Bash and Zsh environments

### Function vs. Scripts Approach
- Use the pragmatic approach to functions vs. scripts:
  - Standalone scripts for complete utilities
  - Source-able libraries for shared functionality
  - Functions when maintaining state is important
- Implement lazy loading for performance-critical components

### Implementation Practices
- Provide exact line numbers when suggesting code snippets
- Write code from a Unix systems developer perspective
- Test in both Bash and Zsh environments
- Ensure proper error handling and security practices
- Create clear documentation with examples
- Use shellcheck for validation where appropriate

### Reference Documents
- `~/.config/rcforge/docs/STYLE_GUIDE.md`
- `~/.config/rcforge/docs/FILE_STRUCTURE_GUIDE.md`
- The v0.3.0 redesign document

## Shell Compatibility Guidelines

### Core System Scripts
- Use Bash 4.0+ features and syntax
- All core scripts must use `#!/usr/bin/env bash`
- Check for Bash version compatibility in critical components
- Provide helpful upgrade instructions for users with older Bash

### End User Scripts
- RC scripts with `_common_` in the name must work in both Bash and Zsh
- RC scripts with `_bash_` must use Bash-specific syntax
- RC scripts with `_zsh_` must use Zsh-specific syntax
- Avoid assumptions about default shell settings

### Example Pattern: Shell Detection
```bash
# Detect current shell
detect_shell() {
  if [[ -n "$ZSH_VERSION" ]]; then
    echo "zsh"
  elif [[ -n "$BASH_VERSION" ]]; then
    echo "bash"
  else
    # Fallback
    basename "$SHELL"
  fi
}
```

When in doubt, use a discussion-first approach to clarify design intent before implementation. Keep simplicity as a guiding principle throughout the development process.
