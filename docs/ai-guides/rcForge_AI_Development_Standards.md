# rcForge Development Standards

## Critical File Location Verification

* **MANDATORY**: Before modifying ANY existing file, verify its exact location by:  
  1. First checking the file in the uploaded documents list  
  2. Cross-referencing with `/docs/FILE_STRUCTURE_GUIDE.md`  
  3. Explicitly confirming the full path when suggesting changes 
* **Always** specify the complete file path when suggesting modifications
* **Never** suggest structural changes without explicit discussion - always highlight these as separate recommendations and obtain approval before implementing. 
* **Never** assume standard locations or make undocumented structural changes

## Project Coordination

### Discussion-First Approach

- Begin with exploring design approaches and considerations
- Evaluate tradeoffs between potential solutions
- Reach agreement on design direction before coding
- Confirm understanding of requirements, even for direct code requests

### File Generation Practices

- Request permission before generating any files
- Confirm complete generation of all files
- Explicitly identify any incomplete file generations
- Add "EOF" comment at the end of every file to verify completeness

## Project Information

- **Name**: rcForge
- **Version**: 0.2.0 (first release candidate in preparation)
- **Repository**: Recently established new GitHub repository

## Standards Adherence

### Reference Documentation

- Consult `docs/STYLE_GUIDE.md` before creating or modifying code
- Review `/docs/FILE_STRUCTURE_GUIDE.md` for file organization principles
- Apply updated standards to new files, with existing files refactored incrementally

### Code Development Principles

- Implement all scripts as artifacts
- Organize code functionally where appropriate
- Position local functions at file beginning
- Place global functions in lib/functions.sh
- Adhere to DRY (Don't Repeat Yourself) principles:
  - Use existing functions when available
  - Implement external calls when reasonable
  - Focus on maintainability and code reuse
- Follow coding and naming conventions in `docs/STYLE_GUIDE.md`

### File Organization

- Adhere to conventions in `docs/STYLE_GUIDE.md`
- Structure files according to `/docs/FILE_STRUCTURE_GUIDE.md`

### Implementation Best Practices

- Provide exact line numbers when suggesting code snippets
- Write code from a Unix systems developer perspective
- Create documentation with technical writing expertise