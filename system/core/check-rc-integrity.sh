#!/usr/bin/env bash
# integrity.sh - Validate rcForge installation integrity
# Author: rcForge Team
# Date: 2025-04-06
# Version: 0.3.0
# Description: Validates the integrity of rcForge installation and environment

# Source required libraries
if [[ -f "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh" ]]; then
  source "${RCFORGE_LIB:-$HOME/.config/rcforge/system/lib}/shell-colors.sh"
else
  # Minimal color definitions if shell-colors.sh is not available
  export RED='\033[0;31m'
  export GREEN='\033[0;32m'
  export YELLOW='\033[0;33m'
  export BLUE='\033[0;34m'
  export CYAN='\033[0;36m'
  export RESET='\033[0m'
  
  # Minimal message functions
  ErrorMessage() { echo -e "${RED}ERROR:${RESET} $1" >&2; }
  WarningMessage() { echo -e "${YELLOW}WARNING:${RESET} $1" >&2; }
  InfoMessage() { echo -e "${BLUE}INFO:${RESET} $1"; }
  SuccessMessage() { echo -e "${GREEN}SUCCESS:${RESET} $1"; }
fi

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_required_files=(
  "rcforge.sh"
  "system/lib/shell-colors.sh"
  "system/lib/utility-functions.sh"
  "system/core/functions.sh"
  "system/utils/seqcheck.sh"
)

readonly gc_min_bash_version="4.0"

# Function: CheckFileIntegrity
# Description: Verify critical files exist
# Usage: CheckFileIntegrity
# Returns: 0 if all files exist, 1 otherwise
CheckFileIntegrity() {
  local missing_files=false
  local rcforge_dir="${RCFORGE_ROOT:-$HOME/.config/rcforge}"
  
  InfoMessage "Checking for critical files..."
  
  for file in "${gc_required_files[@]}"; do
    if [[ ! -f "$rcforge_dir/$file" ]]; then
      ErrorMessage "Missing critical file: $file"
      missing_files=true
    else
      if [[ "$VERBOSE" == "true" ]]; then
        InfoMessage "File exists: $file"
      fi
    fi
  done
  
  if [[ "$missing_files" == "true" ]]; then
    ErrorMessage "File integrity check failed"
    return 1
  else
    SuccessMessage "All critical files present"
    return 0
  fi
}

# Function: CheckPermissions
# Description: Verify directory and file permissions
# Usage: CheckPermissions
# Returns: 0 if permissions are correct, 1 otherwise
CheckPermissions() {
  local permissions_issue=false
  local rcforge_dir="${RCFORGE_ROOT:-$HOME/.config/rcforge}"
  
  InfoMessage "Checking directory permissions..."
  
  # Check main directory
  local main_dir_perms
  main_dir_perms=$(stat -c "%a" "$rcforge_dir" 2>/dev/null || stat -f "%Lp" "$rcforge_dir" 2>/dev/null)
  
  if [[ "$main_dir_perms" != "700" ]]; then
    WarningMessage "Main directory has incorrect permissions: $main_dir_perms (expected 700)"
    permissions_issue=true
  fi
  
  # Check script permissions
  for file in "${gc_required_files[@]}"; do
    if [[ "$file" == *".sh" && -f "$rcforge_dir/$file" ]]; then
      local file_perms
      file_perms=$(stat -c "%a" "$rcforge_dir/$file" 2>/dev/null || stat -f "%Lp" "$rcforge_dir/$file" 2>/dev/null)
      
      if [[ "$file_perms" != "700" ]]; then
        WarningMessage "Script $file has incorrect permissions: $file_perms (expected 700)"
        permissions_issue=true
      fi
    fi
  done
  
  if [[ "$permissions_issue" == "true" ]]; then
    WarningMessage "Permission check found issues"
    return 1
  else
    SuccessMessage "All permissions correct"
    return 0
  fi
}

# Function: CheckEnvironment
# Description: Validate environment variables
# Usage: CheckEnvironment
# Returns: 0 if environment is valid, 1 otherwise
CheckEnvironment() {
  local env_issue=false
  
  InfoMessage "Checking environment variables..."
  
  # Critical variables to check
  local vars=(
    "RCFORGE_ROOT"
    "RCFORGE_SCRIPTS"
    "RCFORGE_LIB"
    "RCFORGE_CORE"
    "RCFORGE_UTILS"
  )
  
  for var in "${vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      WarningMessage "Environment variable $var is not set"
      env_issue=true
    else
      if [[ ! -d "${!var}" ]]; then
        ErrorMessage "Directory for $var does not exist: ${!var}"
        env_issue=true
      elif [[ "$VERBOSE" == "true" ]]; then
        InfoMessage "$var = ${!var}"
      fi
    fi
  done
  
  if [[ "$env_issue" == "true" ]]; then
    WarningMessage "Environment check found issues"
    return 1
  else
    SuccessMessage "Environment variables are properly set"
    return 0
  fi
}

# Function: CheckBashVersion
# Description: Check if Bash version meets requirements
# Usage: CheckBashVersion
# Returns: 0 if Bash version is sufficient, 1 otherwise
CheckBashVersion() {
  InfoMessage "Checking Bash version..."
  
  # Check if using Bash
  if [[ -z "${BASH_VERSION:-}" ]]; then
    WarningMessage "Not running in Bash shell. Current shell: $(basename "$SHELL")"
    return 1
  fi

  # Extract major version number
  local major_version=${BASH_VERSION%%.*}
  local required_major=$(echo "$gc_min_bash_version" | cut -d. -f1)
  
  if [[ "$major_version" -lt "$required_major" ]]; then
    WarningMessage "Bash version $BASH_VERSION is lower than required version $gc_min_bash_version"
    return 1
  else
    SuccessMessage "Bash version $BASH_VERSION meets requirements"
    return 0
  fi
}

# Main function
main() {
  # Process command arguments
  VERBOSE=false
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose|-v)
        VERBOSE=true
        ;;
      --help|-h)
        echo "Usage: integrity.sh [options]"
        echo "Options:"
        echo "  --verbose, -v     Show detailed output"
        echo "  --help, -h        Show this help message"
        return 0
        ;;
      *)
        ErrorMessage "Unknown option: $1"
        return 1
        ;;
    esac
    shift
  done
  
  # Perform integrity checks
  local issues=0
  
  CheckFileIntegrity || ((issues++))
  CheckPermissions || ((issues++))
  CheckEnvironment || ((issues++))
  CheckBashVersion || ((issues++))
  
  # Summary
  echo ""
  if [[ $issues -eq 0 ]]; then
    SuccessMessage "All integrity checks passed"
    return 0
  else
    WarningMessage "Integrity check found $issues issue(s)"
    return 1
  fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
fi

# Export functions for potential reuse
export -f CheckFileIntegrity
export -f CheckPermissions
export -f CheckEnvironment
export -f CheckBashVersion

# EOF
