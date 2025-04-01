# rcForge Commands and Style Guide for Claude

## Build and Test Commands
- `make test` - Run syntax checks and test include system
- `make clean` - Remove build artifacts
- `make release` - Run tests and build packages
- `./utils/test-include.sh` - Test specific includes
  - Options: `--category=path`, `--function=add_to_path`, `--verbose`, `--exit-first`
- `/core/check-checksums.sh` - Verify checksums (use `--fix` to update)

## Style Guidelines
- **Shebang**: Always use `#!/usr/bin/env bash` over hardcoded paths
- **Error Handling**: Set `-o nounset` and `-o errexit` 
- **Variables**:
  - Local: `lowercase_snake_case`
  - Global: `g_lowercase_snake_case`
  - Constants: `c_` (local) or `gc_` (global) prefix
  - Exported: `UPPERCASE_SNAKE_CASE`
  - Booleans: `is_verbose=true` or `has_errors=false`
- **Functions**: 
  - Use PascalCase: `FunctionName()`
  - Document parameters and return values
  - Validate inputs at function start
  - Return 0 for success, non-zero for errors
- **File Structure**: Follow sequence ranges (000-199: Critical, 200-399: Config, etc.)
- **Security**: Restrict permissions, avoid root, use checksums