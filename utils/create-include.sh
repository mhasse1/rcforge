#!/usr/bin/env bash
# create-include.sh - Create a new include function file
# Author: Mark Hasse
# Copyright: Analog Edge LLC
# Date: 2025-03-30
# Version: 0.2.0
# Description: Interactive utility to create new include functions for rcForge

# Import core utility libraries
source shell-colors.sh

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_app_name="rcForge"
readonly gc_version="0.2.0"
readonly gc_default_categories=(
    "path"
    "common"
    "git"
    "network"
    "system"
    "text"
    "web"
    "dev"
    "security"
    "tools"
)

# Configuration variables
export FUNCTION_NAME=""
export CATEGORY=""
export DESCRIPTION=""
export ARGUMENTS=""
export USE_SYSTEM_DIR=false
export FORCE_OVERWRITE=false
export VERBOSE_MODE=false

# Detect project root dynamically
DetectProjectRoot() {
    local possible_roots=(
        "${RCFORGE_ROOT:-}"
        "$HOME/src/rcforge"
        "$HOME/Projects/rcforge"
        "/usr/share/rcforge"
        "/opt/homebrew/share/rcforge"
        "$(brew --prefix 2>/dev/null)/share/rcforge"
        "/opt/local/share/rcforge"
        "/usr/local/share/rcforge"
        "$HOME/.config/rcforge"
    )

    for dir in "${possible_roots[@]}"; do
        if [[ -n "$dir" && -d "$dir" && -f "$dir/rcforge.sh" ]]; then
            echo "$dir"
            return 0
        fi
    done

    # Fallback to user configuration directory
    echo "$HOME/.config/rcforge"
}

# Validate function name
ValidateFunctionName() {
    local name="$1"
    
    # Check if name is empty
    if [[ -z "$name" ]]; then
        ErrorMessage "Function name cannot be empty"
        return 1
    fi

    # Check for valid characters (lowercase with underscores)
    if [[ ! "$name" =~ ^[a-z_][a-z0-9_]*$ ]]; then
        ErrorMessage "Invalid function name. Use lowercase letters, numbers, and underscores. Must start with a letter or underscore."
        return 1
    fi

    return 0
}

# Validate category
ValidateCategory() {
    local category="$1"
    
    # Check if category is empty
    if [[ -z "$category" ]]; then
        ErrorMessage "Category cannot be empty"
        return 1
    fi

    # Check for valid characters (lowercase)
    if [[ ! "$category" =~ ^[a-z][a-z0-9_]*$ ]]; then
        ErrorMessage "Invalid category. Use lowercase letters, numbers, and underscores. Must start with a letter."
        return 1
    fi

    return 0
}

# Parse command-line arguments
ParseArguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --name=*)
                FUNCTION_NAME="${1#*=}"
                ;;
            --category=*)
                CATEGORY="${1#*=}"
                ;;
            --desc=*|--description=*)
                DESCRIPTION="${1#*=}"
                ;;
            --args=*|--arguments=*)
                ARGUMENTS="${1#*=}"
                ;;
            --system)
                USE_SYSTEM_DIR=true
                ;;
            --force|-f)
                FORCE_OVERWRITE=true
                ;;
            --verbose|-v)
                VERBOSE_MODE=true
                ;;
            --help|-h)
                DisplayHelp
                exit 0
                ;;
            --version)
                DisplayVersion
                exit 0
                ;;
            *)
                ErrorMessage "Unknown parameter: $1"
                DisplayHelp
                exit 1
                ;;
        esac
        shift
    done
}

# Display help information
DisplayHelp() {
    SectionHeader "${gc_app_name} Include Function Creator"
    
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --name=NAME          Function name (lowercase, underscore-separated)"
    echo "  --category=CATEGORY  Function category"
    echo "  --desc=DESCRIPTION   Function description"
    echo "  --args=ARGUMENTS     Function arguments (optional)"
    echo "  --system             Create in system include directory"
    echo "  --force, -f          Overwrite existing function"
    echo "  --verbose, -v        Show detailed output"
    echo "  --help, -h           Show this help message"
    echo "  --version            Show version information"
    echo ""
    echo "Examples:"
    echo "  $0 --name=add_to_path --category=path --desc=\"Add directory to PATH\""
    echo "  $0 --name=is_macos --category=common --desc=\"Check if running on macOS\""
}

# Display version information
DisplayVersion() {
    TextBlock "${gc_app_name} Include Function Creator" "$CYAN"
    echo "Version: ${gc_version}"
    echo "Copyright: Analog Edge LLC"
    echo "License: MIT"
}

# Interactive mode for missing arguments
InteractiveMode() {
    # Detect current user's name
    local author
    author=$(git config user.name 2>/dev/null || whoami)

    # Prompt for function name if not provided
    if [[ -z "$FUNCTION_NAME" ]]; then
        while true; do
            read -r -p "Enter function name (lowercase, underscore-separated): " FUNCTION_NAME
            if ValidateFunctionName "$FUNCTION_NAME"; then
                break
            fi
        done
    fi

    # Prompt for category if not provided
    if [[ -z "$CATEGORY" ]]; then
        echo "Available categories:"
        printf '  %s\n' "${gc_default_categories[@]}"
        
        while true; do
            read -r -p "Enter category: " CATEGORY
            if ValidateCategory "$CATEGORY"; then
                break
            fi
        fi
    fi

    # Prompt for description if not provided
    if [[ -z "$DESCRIPTION" ]]; then
        read -r -p "Enter function description: " DESCRIPTION
    fi

    # Prompt for arguments if not provided
    if [[ -z "$ARGUMENTS" ]]; then
        read -r -p "Enter function arguments (optional, space-separated): " ARGUMENTS
    fi

    # Ask about system vs user directory
    if [[ "$USE_SYSTEM_DIR" == false ]]; then
        read -r -p "Create in system include directory? (y/N): " system_choice
        if [[ "$system_choice" =~ ^[Yy]$ ]]; then
            USE_SYSTEM_DIR=true
        fi
    fi
}

# Determine include directory
DetermineIncludeDirectory() {
    local base_dir="$1"
    local user_include_dir="$HOME/.config/rcforge/include"
    local system_include_dir="${base_dir}/include"

    if [[ "$USE_SYSTEM_DIR" == true ]]; then
        # Require root/sudo for system directory
        if [[ $EUID -ne 0 ]]; then
            ErrorMessage "System include directory requires root/sudo privileges"
            return 1
        fi
        echo "$system_include_dir"
    else
        echo "$user_include_dir"
    fi
}

# Create the include function file
CreateIncludeFile() {
    local include_dir="$1"
    local category_dir="$include_dir/$CATEGORY"
    
    # Create category directory if it doesn't exist
    mkdir -p "$category_dir"

    # Determine file path
    local function_file="$category_dir/${FUNCTION_NAME}.sh"

    # Check for existing file
    if [[ -f "$function_file" && "$FORCE_OVERWRITE" == false ]]; then
        ErrorMessage "Function file already exists: $function_file"
        echo "Use --force to overwrite."
        return 1
    fi

    # Prepare author name
    local author
    author=$(git config user.name 2>/dev/null || whoami)

    # Create function file content
    cat > "$function_file" << EOF
#!/usr/bin/env bash
# ${FUNCTION_NAME}.sh - ${DESCRIPTION}
# Category: $CATEGORY
# Author: $author
# Date: $(date +%F)

# Function: ${FUNCTION_NAME}
# Description: ${DESCRIPTION}
# Usage: ${FUNCTION_NAME} ${ARGUMENTS}
${FUNCTION_NAME}() {
    # Input validation
    if [[ \$# -eq 0 ]]; then
        ErrorMessage "No arguments provided"
        return 1
    fi

    # Function implementation
    local result=""
    
    # TODO: Implement function logic
    ErrorMessage "Function not implemented yet"
    return 1
}

# Export the function to make it available in other scripts
export -f ${FUNCTION_NAME}
EOF

    # Make file executable
    chmod +x "$function_file"

    # Verbose output
    if [[ "$VERBOSE_MODE" == true ]]; then
        SuccessMessage "Created function file: $function_file"
        echo "  Category:     $CATEGORY"
        echo "  Description: $DESCRIPTION"
        echo "  Arguments:   $ARGUMENTS"
    fi
}

# Offer to edit the newly created file
OfferToEdit() {
    local function_file="$1"
    
    read -r -p "Do you want to edit the file now? (y/N): " edit_choice
    
    if [[ "$edit_choice" =~ ^[Yy]$ ]]; then
        # Try to determine the best editor
        local editor
        editor=$(command -v code || command -v vim || command -v nano)
        
        if [[ -n "$editor" ]]; then
            "$editor" "$function_file"
        else
            ErrorMessage "No editor found. Please edit the file manually."
        fi
    fi
}

# Main script execution
Main() {
    # Detect project root
    local RCFORGE_DIR
    RCFORGE_DIR=$(DetectProjectRoot)

    # Parse command-line arguments
    ParseArguments "$@"

    # Display header
    SectionHeader "${gc_app_name} Include Function Creator"

    # Run interactive mode if not all parameters are provided
    if [[ -z "$FUNCTION_NAME" || -z "$CATEGORY" ]]; then
        InteractiveMode
    fi

    # Validate inputs
    ValidateFunctionName "$FUNCTION_NAME" || exit 1
    ValidateCategory "$CATEGORY" || exit 1

    # Determine include directory
    local include_dir
    include_dir=$(DetermineIncludeDirectory "$RCFORGE_DIR") || exit 1

    # Create the include function file
    CreateIncludeFile "$include_dir" || exit 1

    # Offer to edit the file
    OfferToEdit "$include_dir/$CATEGORY/${FUNCTION_NAME}.sh"
}

# Entry point - execute only if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    Main "$@"
fi
