#!/bin/bash
# core/bash-version-check.sh
# Shared function to check Bash version requirements

# Function to check if Bash meets version requirements
check_bash_version() {
  # Only check if using Bash
  if [[ -n "$BASH_VERSION" ]]; then
    local major_version=${BASH_VERSION%%.*}
    
    if [[ "$major_version" -lt 4 ]]; then
      # Only use colors if they're defined
      if [[ -n "${RED:-}" && -n "${YELLOW:-}" && -n "${RESET:-}" ]]; then
        echo -e "${RED}Error: rcForge v0.2.0 requires Bash 4.0 or higher${RESET}"
        echo -e "${YELLOW}Your current Bash version is: $BASH_VERSION${RESET}"
      else
        echo "Error: rcForge v0.2.0 requires Bash 4.0 or higher"
        echo "Your current Bash version is: $BASH_VERSION"
      fi
      
      echo ""
      echo "On macOS, you can install a newer version with Homebrew:"
      echo "  brew install bash"
      echo ""
      echo "Then add it to your available shells:"
      echo "  sudo bash -c 'echo $(brew --prefix)/bin/bash >> /etc/shells'"
      echo ""
      echo "And optionally set it as your default shell:"
      echo "  chsh -s $(brew --prefix)/bin/bash"
      echo ""
      
      # Return the error status
      return 1
    fi
  fi
  
  # Return success if using Zsh or Bash 4+
  return 0
}

# Export the function
export -f check_bash_version
# EOF
