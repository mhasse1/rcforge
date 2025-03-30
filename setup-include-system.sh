#!/bin/bash
# setup-include-system.sh - Set up rcForge include system function structure
# Author: Mark Hasse
# Date: March 29, 2025

set -e  # Exit on error
set -o nounset  # Treat unset variables as an error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Determine project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel)"
INCLUDE_DIR="$PROJECT_ROOT/include"

# Function categories
CATEGORIES=(
    "common"
    "path"
    "git"
    "network"
    "system"
    "text"
    "web"
    "dev"
    "security"
    "tools"
)

# Create directory structure
create_directory_structure() {
    echo -e "${CYAN}Creating include system directories...${RESET}"

    # Create base include directory
    mkdir -p "$INCLUDE_DIR"

    # Create subdirectories for each category
    for category in "${CATEGORIES[@]}"; do
        mkdir -p "$INCLUDE_DIR/$category"
        echo -e "${GREEN}✓ Created category directory: $INCLUDE_DIR/$category${RESET}"
    done
}

# Create common utility functions
create_common_functions() {
    local common_dir="$INCLUDE_DIR/common"

    echo -e "${CYAN}Creating common utility functions...${RESET}"

    # is_macos function
    cat > "$common_dir/is_macos.sh" << 'EOF'
#!/bin/bash
# is_macos.sh - Detect if the current system is macOS
# Category: common

is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Export the function
export -f is_macos
# EOF
EOF

    # is_linux function
    cat > "$common_dir/is_linux.sh" << 'EOF'
#!/bin/bash
# is_linux.sh - Detect if the current system is Linux
# Category: common

is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# Export the function
export -f is_linux
# EOF
EOF

    # cmd_exists function
    cat > "$common_dir/cmd_exists.sh" << 'EOF'
#!/bin/bash
# cmd_exists.sh - Check if a command exists
# Category: common

cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Export the function
export -f cmd_exists
# EOF
EOF

    # set_debug_mode function
    cat > "$common_dir/set_debug_mode.sh" << 'EOF'
#!/bin/bash
# set_debug_mode.sh - Enable or disable debug mode for shell scripts
# Category: common

set_debug_mode() {
    local mode="${1:-on}"

    if [[ "$mode" == "on" ]]; then
        export SHELL_DEBUG=1
        set -x
    else
        unset SHELL_DEBUG
        set +x
    fi
}

# Export the function
export -f set_debug_mode
# EOF
EOF

    echo -e "${GREEN}✓ Common functions created successfully${RESET}"
}

# Create path management functions
create_path_functions() {
    local path_dir="$INCLUDE_DIR/path"

    echo -e "${CYAN}Creating path management functions...${RESET}"

    # add_to_path function
    cat > "$path_dir/add_to_path.sh" << 'EOF'
#!/bin/bash
# add_to_path.sh - Add a directory to the beginning of PATH
# Category: path

add_to_path() {
    local dir="$1"
    if [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]]; then
        export PATH="$dir:$PATH"
        return 0
    fi
    return 1
}

# Export the function
export -f add_to_path
# EOF
EOF

    # append_to_path function
    cat > "$path_dir/append_to_path.sh" << 'EOF'
#!/bin/bash
# append_to_path.sh - Append a directory to the end of PATH
# Category: path

append_to_path() {
    local dir="$1"
    if [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]]; then
        export PATH="$PATH:$dir"
        return 0
    fi
    return 1
}

# Export the function
export -f append_to_path
# EOF
EOF

    # show_path function
    cat > "$path_dir/show_path.sh" << 'EOF'
#!/bin/bash
# show_path.sh - Display PATH contents in a readable format
# Category: path

show_path() {
    echo "Current PATH:"
    echo "$PATH" | tr ':' '\n' | nl
}

# Export the function
export -f show_path
# EOF
EOF

    echo -e "${GREEN}✓ Path management functions created successfully${RESET}"
}

# Set appropriate permissions for all files
set_permissions() {
    echo -e "${CYAN}Setting permissions for include system...${RESET}"

    # Set directory permissions
    find "$INCLUDE_DIR" -type d -exec chmod 755 {} \;

    # Set file permissions
    find "$INCLUDE_DIR" -type f -name "*.sh" -exec chmod 644 {} \;

    echo -e "${GREEN}✓ Permissions set successfully${RESET}"
}

# Main setup function
main() {
    # Check if in a git repository
    if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
        echo -e "${RED}Error: Must be run from within the git repository.${RESET}"
        exit 1
    fi

    # Create directory structure
    create_directory_structure

    # Create functions
    create_common_functions
    create_path_functions

    # Set permissions
    set_permissions

    echo -e "\n${GREEN}✓ rcForge Include System Setup Complete!${RESET}"
    echo -e "${YELLOW}Include functions created in:${RESET}"
    echo "  $INCLUDE_DIR"
}

# Execute main function
main "$@"
# EOF
