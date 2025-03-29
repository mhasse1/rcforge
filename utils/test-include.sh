#!/bin/bash
# test-include.sh - Test script for the rcForge include system
# Author: Mark Hasse
# Date: March 28, 2025

set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color

# Make sure Bash version is compatible
if [[ -n "$BASH_VERSION" ]]; then
  BASH_MAJOR=${BASH_VERSION%%.*}
  if [[ "$BASH_MAJOR" -lt 4 ]]; then
    echo -e "${RED}Error: rcForge v2.0.0 requires Bash 4.0 or higher for the include system${RESET}"
    echo -e "${YELLOW}Your current Bash version is: $BASH_VERSION${RESET}"
    echo ""
    echo "On macOS, you can install a newer version with Homebrew:"
    echo "  brew install bash"
    echo ""
    echo "Then add it to your available shells:"
    echo "  sudo bash -c 'echo /opt/homebrew/bin/bash >> /etc/shells'"
    echo ""
    echo "And optionally set it as your default shell:"
    echo "  chsh -s /opt/homebrew/bin/bash"
    echo ""
    exit 1
  fi
fi

# Display header
echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│ rcForge Include System Test                          │${RESET}"
echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
echo ""

# Detect if we're running in development mode
if [[ -n "${RCFORGE_DEV}" ]]; then
  # Development mode
  RCFORGE_DIR="$HOME/src/rcforge"
  SYS_INCLUDE_DIR="$RCFORGE_DIR/include"
  SYS_LIB_DIR="$RCFORGE_DIR/src/lib"
else
  # Production mode - Detect system installation first, then user installation
  if [[ -d "/usr/share/rcforge" ]]; then
    # System installation on Linux
    RCFORGE_SYS_DIR="/usr/share/rcforge"
  elif [[ -d "/opt/homebrew/share/rcforge" ]]; then
    # Homebrew installation on Apple Silicon
    RCFORGE_SYS_DIR="/opt/homebrew/share/rcforge"
  elif [[ -n "$(which brew 2>/dev/null)" && -d "$(brew --prefix 2>/dev/null)/share/rcforge" ]]; then
    # Homebrew installation (generic)
    RCFORGE_SYS_DIR="$(brew --prefix)/share/rcforge"
  else
    # Fallback to expected user location
    RCFORGE_SYS_DIR="$HOME/.config/rcforge"
  fi
  SYS_INCLUDE_DIR="$RCFORGE_SYS_DIR/include"
  SYS_LIB_DIR="$RCFORGE_SYS_DIR/src/lib"
fi

USER_INCLUDE_DIR="$HOME/.config/rcforge/include"

# Parse command line arguments
verbose=0
category=""
specific_function=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --verbose|-v)
      verbose=1
      ;;
    --category=*)
      category="${1#*=}"
      ;;
    --function=*)
      specific_function="${1#*=}"
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --verbose, -v          Show more detailed output"
      echo "  --category=CATEGORY    Test only specified category"
      echo "  --function=FUNCTION    Test only specified function"
      echo "  --help                 Show this help message"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown parameter: $1"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
  shift
done

# Simple debug function
debug_echo() {
  echo "DEBUG: $*"
}

# Source include functions
if [[ -f "$SYS_LIB_DIR/include-functions.sh" ]]; then
  source "$SYS_LIB_DIR/include-functions.sh"
  echo -e "${GREEN}✓ Loaded include functions from $SYS_LIB_DIR/include-functions.sh${RESET}"
else
  echo -e "${RED}Error: include-functions.sh not found${RESET}"
  echo "Expected location: $SYS_LIB_DIR/include-functions.sh"
  exit 1
fi

# Print system information
echo -e "${CYAN}System information:${RESET}"
echo -e "  User include directory: ${YELLOW}$USER_INCLUDE_DIR${RESET}"
echo -e "  System include directory: ${YELLOW}$SYS_INCLUDE_DIR${RESET}"
echo -e "  System library directory: ${YELLOW}$SYS_LIB_DIR${RESET}"
echo ""

# List available functions
echo -e "${CYAN}Available functions:${RESET}"
if [[ -n "$category" ]]; then
  list_available_functions "$category"
else
  list_available_functions
fi
echo ""

# Test individual function
test_include_function() {
  local category="$1"
  local function_name="$2"
  
  echo -e "${YELLOW}Testing include_function $category $function_name...${RESET}"
  
  if include_function "$category" "$function_name"; then
    echo -e "${GREEN}✓ Successfully included function: $function_name${RESET}"
    
    # Test if the function is actually available
    if type -t "$function_name" >/dev/null 2>&1; then
      echo -e "${GREEN}✓ Function $function_name is available${RESET}"
      
      # Try to run the function
      if [[ $verbose -eq 1 ]]; then
        echo -e "${CYAN}Function output:${RESET}"
        "$function_name" || echo -e "${YELLOW}Function executed with non-zero return code${RESET}"
      fi
    else
      echo -e "${RED}× Function $function_name is not available${RESET}"
    fi
  else
    echo -e "${RED}× Failed to include function: $function_name${RESET}"
  fi
  
  echo ""
}

# Test category
test_include_category() {
  local category="$1"
  
  echo -e "${YELLOW}Testing include_category $category...${RESET}"
  
  if include_category "$category"; then
    echo -e "${GREEN}✓ Successfully included category: $category${RESET}"
    
    # List all functions in the category
    local user_functions=()
    if [[ -d "$USER_INCLUDE_DIR/$category" ]]; then
      for func_file in "$USER_INCLUDE_DIR/$category"/*.sh; do
        if [[ -f "$func_file" ]]; then
          local function_name=$(basename "$func_file" .sh)
          user_functions+=("$function_name")
        fi
      done
    fi
    
    local sys_functions=()
    if [[ -d "$SYS_INCLUDE_DIR/$category" ]]; then
      for func_file in "$SYS_INCLUDE_DIR/$category"/*.sh; do
        if [[ -f "$func_file" ]]; then
          local function_name=$(basename "$func_file" .sh)
          # Skip if already in user functions
          if [[ ! " ${user_functions[@]} " =~ " $function_name " ]]; then
            sys_functions+=("$function_name")
          fi
        fi
      done
    fi
    
    # Test each function
    local all_functions=("${user_functions[@]}" "${sys_functions[@]}")
    if [[ ${#all_functions[@]} -eq 0 ]]; then
      echo -e "${YELLOW}No functions found in category: $category${RESET}"
    else
      echo -e "${CYAN}Testing ${#all_functions[@]} functions in category $category...${RESET}"
      for function_name in "${all_functions[@]}"; do
        if type -t "$function_name" >/dev/null 2>&1; then
          echo -e "${GREEN}✓ Function $function_name is available${RESET}"
          
          # Execute function if verbose mode
          if [[ $verbose -eq 1 ]]; then
            echo -e "${CYAN}Function $function_name output:${RESET}"
            "$function_name" || echo -e "${YELLOW}Function executed with non-zero return code${RESET}"
          fi
        else
          echo -e "${RED}× Function $function_name is not available${RESET}"
        fi
      done
    fi
  else
    echo -e "${RED}× Failed to include category: $category${RESET}"
  fi
  
  echo ""
}

# Function to create test include files
create_test_includes() {
  echo -e "${CYAN}Creating temporary test includes...${RESET}"
  local test_dir="/tmp/rcforge-test-includes"
  
  # Remove old test directory if it exists
  rm -rf "$test_dir"
  
  # Create test include directory
  mkdir -p "$test_dir/test"
  
  # Create a test function
  cat > "$test_dir/test/hello.sh" << 'EOF'
#!/bin/bash
# Test function

hello() {
  echo "Hello from test function!"
  return 0
}

export -f hello
EOF
  chmod +x "$test_dir/test/hello.sh"
  
  # Create a test function with dependencies
  cat > "$test_dir/test/greeting.sh" << 'EOF'
#!/bin/bash
# Test function with dependency

# Dependency: test/hello
include_function test hello

greeting() {
  echo "This is a greeting function that depends on hello()"
  hello
  echo "Dependency called!"
  return 0
}

export -f greeting
EOF
  chmod +x "$test_dir/test/greeting.sh"
  
  # Update paths to include test directory
  export RCFORGE_TEST_INCLUDE="$test_dir"
  export _CATEGORY_PATHS["test"]="$test_dir/test"
  
  echo -e "${GREEN}✓ Created test includes at $test_dir${RESET}"
  echo ""
}

# Main testing
if [[ -n "$specific_function" && -n "$category" ]]; then
  # Test specific function
  test_include_function "$category" "$specific_function"
elif [[ -n "$category" ]]; then
  # Test entire category
  test_include_category "$category"
else
  # Test common functions
  echo -e "${CYAN}Testing common include functions...${RESET}"
  
  # Test path functions first
  if [[ -d "$SYS_INCLUDE_DIR/path" ]]; then
    test_include_function "path" "add_to_path"
    test_include_function "path" "append_to_path"
    test_include_function "path" "show_path"
  else
    echo -e "${YELLOW}Path category not found, skipping...${RESET}"
  fi
  
  # Test common functions
  if [[ -d "$SYS_INCLUDE_DIR/common" ]]; then
    test_include_function "common" "is_macos"
    test_include_function "common" "is_linux"
    test_include_category "common"
  else
    echo -e "${YELLOW}Common category not found, skipping...${RESET}"
  fi
  
  # Create and test temporary functions with dependencies
  create_test_includes
  test_include_function "test" "hello"
  test_include_function "test" "greeting"
  
  echo -e "${GREEN}Include system tests completed${RESET}"
fi
# EOF