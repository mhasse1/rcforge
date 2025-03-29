#!/bin/bash
# rcforge-setup - Interactive setup script for rcForge

# Set strict error handling
set -o nounset
set -o errexit

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Configuration paths
RCFORGE_HOME="${HOME}/.config/rcforge"
BACKUP_BASE="${HOME}/.config/rcforge-backup"

# Verbose flag
VERBOSE=0

# Parse command line arguments
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --verbose|-v) 
                VERBOSE=1
                ;;
            --help|-h)
                display_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown parameter: $1${RESET}"
                display_help
                exit 1
                ;;
        esac
        shift
    done
}

# Display help information
display_help() {
    echo "Usage: rcforge-setup [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --verbose, -v    Enable verbose output"
    echo "  --help, -h       Show this help message"
    echo ""
}

# Log verbose messages
verbose_log() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${BLUE}VERBOSE:${RESET} $*"
    fi
}

# Display a warning header
display_warning_header() {
    echo ""
    echo -e "${YELLOW}██╗    ██╗ █████╗ ██████╗ ███╗   ██╗██╗███╗   ██╗ ██████╗ ${RESET}"
    echo -e "${YELLOW}██║    ██║██╔══██╗██╔══██╗████╗  ██║██║████╗  ██║██╔════╝ ${RESET}"
    echo -e "${YELLOW}██║ █╗ ██║███████║██████╔╝██╔██╗ ██║██║██╔██╗ ██║██║  ███╗${RESET}"
    echo -e "${YELLOW}██║███╗██║██╔══██║██╔══██╗██║╚██╗██║██║██║╚██╗██║██║   ██║${RESET}"
    echo -e "${YELLOW}╚███╔███╔╝██║  ██║██║  ██║██║ ╚████║██║██║ ╚████║╚██████╔╝${RESET}"
    echo -e "${YELLOW} ╚══╝╚══╝ ╚═╝  ╚═╝╚═════╝      ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ${RESET}"
    echo ""
}

# Perform backup of existing rcForge configuration
backup_existing_config() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_dir="${BACKUP_BASE}-${timestamp}"

    display_warning_header
    echo -e "${YELLOW}An existing rcForge configuration was detected.${RESET}"
    echo ""
    echo -e "${CYAN}Would you like to create a backup before proceeding? [Y/n]${RESET}"
    read -r backup_response

    # Default to yes if no response
    backup_response=${backup_response:-Y}

    if [[ "$backup_response" =~ ^[Yy]$ ]]; then
        verbose_log "Creating backup of existing configuration"
        mkdir -p "$backup_dir"
        cp -r "$RCFORGE_HOME"/* "$backup_dir"
        
        echo -e "${GREEN}✓ Backup created at: ${backup_dir}${RESET}"
        echo ""
    else
        echo -e "${YELLOW}Skipping backup.${RESET}"
    fi

    echo -e "${CYAN}Do you want to continue with setup? [Y/n]${RESET}"
    read -r continue_response

    # Default to yes if no response
    continue_response=${continue_response:-Y}

    if [[ ! "$continue_response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Setup aborted.${RESET}"
        exit 0
    fi
}

# Create initial rcForge configuration structure
create_config_structure() {
    verbose_log "Creating rcForge configuration directories"

    # Create base directories with restrictive permissions
    mkdir -p "$RCFORGE_HOME/scripts"
    mkdir -p "$RCFORGE_HOME/include"
    mkdir -p "$RCFORGE_HOME/exports"
    mkdir -p "$RCFORGE_HOME/docs"

    chmod 700 "$RCFORGE_HOME"
    chmod 700 "$RCFORGE_HOME/scripts"
    chmod 700 "$RCFORGE_HOME/include"
    chmod 700 "$RCFORGE_HOME/exports"
    chmod 700 "$RCFORGE_HOME/docs"

    # Copy example configurations if not already present
    if [[ -d "/usr/share/rcforge/scripts" ]]; then
        cp -n /usr/share/rcforge/scripts/* "$RCFORGE_HOME/scripts/" 2>/dev/null || true
    fi

    # Copy documentation
    if [[ -d "/usr/share/doc/rcforge" ]]; then
        cp -n /usr/share/doc/rcforge/README.md "$RCFORGE_HOME/docs/" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Configuration structure created${RESET}"
}

# Final setup message
display_final_message() {
    echo ""
    echo -e "${GREEN}┌──────────────────────────────────────────────────────┐${RESET}"
    echo -e "${GREEN}│ rcForge Setup Complete                               │${RESET}"
    echo -e "${GREEN}└──────────────────────────────────────────────────────┘${RESET}"
    echo ""
    echo -e "${YELLOW}Configuration Notes:${RESET}"
    echo "- All configuration files are set to 700/600 permissions"
    echo "- This means only you can read/write/execute these files"
    echo ""
    echo -e "${CYAN}Next Steps:${RESET}"
    echo "1. Add your custom configurations to: ${HOME}/.config/rcforge/scripts/"
    echo "2. Explore example configurations in the same directory"
    echo "3. Source your shell RC file or start a new shell"
    echo ""
    echo -e "${BLUE}Happy Scripting! 🚀${RESET}"
}

# Main setup function
main() {
    parse_arguments "$@"

    # Check if rcForge is already configured
    if [[ -d "$RCFORGE_HOME" ]]; then
        backup_existing_config
    fi

    create_config_structure
    display_final_message
}

# Execute main function
main "$@"
# EOF