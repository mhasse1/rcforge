# rcForge AI Development Standards (v0.3.0)

## Critical File Location Verification

* **MANDATORY**: Before modifying ANY existing file, verify its exact location by:  
  1. First checking the file in the uploaded documents list  
  2. Cross-referencing with the updated `~/.config/rcforge/docs/FILE_STRUCTURE_GUIDE.md`  
  3. Explicitly confirming the full path when suggesting changes 
* **Always** specify the complete file path when suggesting modifications
* **Never** suggest structural changes without explicit discussion - always highlight these as separate recommendations and obtain approval before implementing
* **Never** assume standard locations or make undocumented structural changes
* **Note the new directory structure** - All paths are now relative to `~/.config/rcforge/`

## Project Coordination

### Discussion-First Approach

- Begin with exploring design approaches and considerations
- Evaluate tradeoffs between potential solutions
- Reach agreement on design direction before coding
- Confirm understanding of requirements, even for direct code requests
- Consider user-override implications for any system utilities

### File Generation Practices

- Request permission before generating any files
- Confirm complete generation of all files
- Explicitly identify any incomplete file generations
- Add "EOF" comment at the end of every file to verify completeness
- Validate conformance to the rc-scripts naming convention for configuration files
- Ensure all utilities properly support the RC command framework

## Project Information

- **Name**: rcForge
- **Version**: 0.3.0 (redesign in progress)
- **Repository**: GitHub repository
- **Architecture**: User-centric design with no system-wide installation

## Standards Adherence

### Reference Documentation

- Consult `~/.config/rcforge/docs/STYLE_GUIDE.md` before creating or modifying code
- Review `~/.config/rcforge/docs/FILE_STRUCTURE_GUIDE.md` for file organization principles
- Apply updated standards to new files, with existing files refactored incrementally
- Familiarize yourself with the v0.3.0 redesign document for architectural principles

### Code Development Principles

- Implement all scripts as artifacts
- Follow the pragmatic approach to functions vs. scripts:
  - Use standalone scripts for complete RC utilities
  - Create source-able libraries for shared functionality
  - Use functions when maintaining state is important
- Implement lazy loading patterns for performance-critical components
- Support the user override system in all utilities
- Adhere to DRY (Don't Repeat Yourself) principles:
  - Use existing functions when available
  - Implement external calls when reasonable
  - Focus on maintainability and code reuse
- Follow coding and naming conventions in `~/.config/rcforge/docs/STYLE_GUIDE.md`

### RC Command Framework Standards

- All utilities must support the RC command interface:
  - `help` subcommand that displays detailed usage information
  - `summary` subcommand that returns a one-line description
- Include clear documentation with examples
- Support user override by avoiding hardcoded paths
- Design with modularity in mind

### RC Scripts Development

- Follow the sequence-based naming convention:
  ```
  ###_[hostname|global]_[environment]_[description].sh
  ```
- Respect the sequence number ranges for appropriate functionality
- Use shell-specific scripts only when necessary
- Implement appropriate error handling

### File Organization

- Adhere to conventions in `~/.config/rcforge/docs/STYLE_GUIDE.md`
- Structure files according to `~/.config/rcforge/docs/FILE_STRUCTURE_GUIDE.md`
- Place system utilities in `~/.config/rcforge/system/utils/`
- Place user utilities in `~/.config/rcforge/utils/`
- Place RC scripts in `~/.config/rcforge/rc-scripts/`

### Implementation Best Practices

- Provide exact line numbers when suggesting code snippets
- Write code from a Unix systems developer perspective
- Create documentation with technical writing expertise
- Test all utilities and scripts in both Bash and Zsh environments
- Ensure all utilities check for and handle error conditions gracefully

### Security Considerations

- Avoid using or suggesting root-level operations
- Maintain strict file permissions (700 for directories, 700 for scripts, 600 for configs)
- Verify secure handling of user input in all utilities
- Implement appropriate input validation

## New for v0.3.0: Testing Standards

- Test RC scripts in both Bash and Zsh environments
- Verify lazy loading functionality works as expected
- Test user override capability for utilities
- Ensure all utilities function properly through the RC command interface
- Validate sequence-based loading works as expected

## New for v0.3.0: Documentation Standards

- Create clear, concise help documentation for all utilities
- Include practical examples in all help text
- Ensure documentation follows markdown standards
- Add appropriate source comments
- Update documentation when implementing changes
- Ensure all RC command utilities have proper summary text for `rc help`

By adhering to these standards, we ensure that AI-assisted development for rcForge v0.3.0 remains consistent, maintainable, and aligned with the redesigned architecture.

# EOF
