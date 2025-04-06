# rcForge Project Instructions (v0.3.0)

## Project Information
- **Name**: rcForge
- **Version**: 0.3.0 (redesign in progress)
- **Structure**: User-centric design with installation in `~/.config/rcforge/`

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

## Code Standards

### RC Scripts Development
- Follow naming convention: `###_[hostname|global]_[environment]_[description].sh`
- Place all RC scripts in `~/.config/rcforge/rc-scripts/`

### RC Command Utilities
- Place system utilities in `~/.config/rcforge/system/utils/`
- Place user utilities in `~/.config/rcforge/utils/`
- Support both `help` and `summary` subcommands
- Design with user overrides in mind

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

### Reference Documents
- `~/.config/rcforge/docs/STYLE_GUIDE.md`
- `~/.config/rcforge/docs/FILE_STRUCTURE_GUIDE.md`
- The v0.3.0 redesign document

When in doubt, use a discussion-first approach to clarify design intent before implementation.

# EOF
