#!/usr/bin/env bash
# rcforge-setup.sh - Interactive setup utility for rcForge
# Author: Mark Hasse
# Copyright: Analog Edge LLC
# Date: 2025-03-30
# Version: 0.2.0
# Description: Guides users through rcForge configuration and initialization

# Import core utility libraries
source shell-colors.sh

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Global constants
readonly gc_app_name="rcForge"
readonly gc_version="0.2.0"
readonly gc_config_base_dir="${HOME}/.config/rcforge"
readonly gc_default_scripts_dir="${gc_config_base_dir}/scripts"
readonly gc_default_include_dir="${gc_config_base_dir}/include"

# Configuration variables
export INTERACTIVE_MODE=true
export MINIMAL_SETUP=false
export OVERWRITE_EXISTING=false
export VERBOSE_MODE=false
export TARGET_SHELL=""
export HOSTNAME=""

# Detect current shell
DetectCurrentShell() {
    if [[ -n "$BASH_VERSION" ]]; then
        echo "bash"
    elif [[ -n "$ZSH_VERSION" ]]; then
        echo "zsh"
    else
        # Fallback to checking $SHELL
        basename "$SHELL"
    fi
}

# Validate shell type
ValidateShellType() {
    local shell="$1"
    if [[ "$shell" != "bash" && "$shell" != "zsh" ]]; then
        ErrorMessage "Invalid shell type. Must be 'bash' or 'zsh'."
        return 1
    fi
    return 0
}

# Parse command-line arguments
ParseArguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --non-interactive)
                INTERACTIVE_MODE=false
                ;;
            --minimal)
                MINIMAL_SETUP=true
                ;;
            --overwrite)
                OVERWRITE_EXISTING=true
                ;;
            --verbose|-v)
                VERBOSE_MODE=true
                ;;
            --shell=*)
                TARGET_SHELL="${1#*=}"
                ValidateShellType "$TARGET_SHELL" || exit 1
                ;;
            --hostname=*)
                HOSTNAME="${1#*=}"
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

    # Set defaults if not specified
    TARGET_SHELL="${TARGET_SHELL:-$(DetectCurrentShell)}"
    HOSTNAME="${HOSTNAME:-$(hostname | cut -d. -f1)}"
}

# Display help information
DisplayHelp() {
    SectionHeader "${gc_app_name} Setup Utility"
    
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --non-interactive    Run without interactive prompts"
    echo "  --minimal            Perform minimal configuration"
    echo "  --overwrite          Overwrite existing configurations"
    echo "  --verbose, -v        Show detailed output"
    echo "  --shell=TYPE         Specify target shell (bash/zsh)"
    echo "  --hostname=NAME      Specify hostname for configuration"
    echo "  --help, -h           Show this help message"
    echo "  --version            Show version information"
    echo ""
    echo "Examples:"
    echo "  $0                   Interactive setup"
    echo "  $0 --non-interactive --minimal  Minimal non-interactive setup"
    echo "  $0 --shell=bash --overwrite   Overwrite Bash configurations"
}

# Display version information
DisplayVersion() {
    TextBlock "${gc_app_name} Setup Utility" "$CYAN"
    echo "Version: ${gc_version}"
    echo "Copyright: Analog Edge LLC"
    echo "License: MIT"
}

# Create base directory structure
CreateDirectoryStructure() {
    local dirs=(
        "${gc_config_base_dir}"
        "${gc_default_scripts_dir}"
        "${gc_default_include_dir}"
        "${gc_config_base_dir}/checksums"
        "${gc_config_base_dir}/exports"
        "${gc_config_base_dir}/docs"
    )

    InfoMessage "Creating rcForge directory structure..."
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            chmod 700 "$dir"
            if [[ "$VERBOSE_MODE" == true ]]; then
                echo "  Created: $dir"
            fi
        else
            if [[ "$VERBOSE_MODE" == true ]]; then
                echo "  Exists:  $dir"
            fi
        fi
    done
}

# Create sample configuration files
CreateSampleConfigurations() {
    local scripts_dir="$1"
    local shell_type="$2"
    local hostname="$3"

    # Skip if minimal setup
    if [[ "$MINIMAL_SETUP" == true ]]; then
        WarningMessage "Skipping sample configurations (minimal setup)"
        return 0
    }

    InfoMessage "Creating sample configuration files..."

    # Global environment configuration
    local env_config="${scripts_dir}/100_global_common_environment.sh"
    if [[ ! -f "$env_config" || "$OVERWRITE_EXISTING" == true ]]; then
        cat > "$env_config" << EOF
#!/usr/bin/env bash
# Global environment variables

# Include required functions 
include_function common is_macos
include_function common is_linux

# Set default editor based on availability
if command -v vim >/dev/null 2>&1; then
    export EDITOR="vim"
    export VISUAL="vim"
elif command -v nano >/dev/null 2>&1; then
    export EDITOR="nano"
    export VISUAL="nano"
fi

# Set terminal type and colors
export TERM="xterm-256color"
export CLICOLOR=1

# Set locale
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

# History settings
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth
EOF
        chmod 700 "$env_config"
    fi

    # Shell-specific configuration
    local shell_config
    if [[ "$shell_type" == "bash" ]]; then
        shell_config="${scripts_dir}/300_global_bash_prompt.sh"
        if [[ ! -f "$shell_config" || "$OVERWRITE_EXISTING" == true ]]; then
            cat > "$shell_config" << EOF
#!/usr/bin/env bash
# Bash prompt configuration

# Include required functions
include_function common is_macos

# Define colors if terminal supports them
if [[ -x /usr/bin/tput ]] && tput setaf 1 >/dev/null 2>&1; then
    RESET="\[\033[0m\]"
    BOLD="\[\033[1m\]"
    BLUE="\[\033[38;5;27m\]"
    GREEN="\[\033[38;5;35m\]"
    YELLOW="\[\033[38;5;214m\]"
    CYAN="\[\033[38;5;45m\]"
else
    RESET=""
    BOLD=""
    BLUE=""
    GREEN=""
    YELLOW=""
    CYAN=""
fi

# Git status function
get_git_status() {
    if ! command -v git >/dev/null 2>&1; then
        return
    fi

    local branch
    branch=\$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)
    
    if [[ -n "\$branch" ]]; then
        echo " \${GREEN}(\$branch)\${RESET}"
    fi
}

# Define the main prompt
PS1="\n\${GREEN}\u@\h\${RESET} \${BLUE}\w\${RESET}\$(get_git_status)\n\$ "
EOF
            chmod 700 "$shell_config"
        fi
    elif [[ "$shell_type" == "zsh" ]]; then
        shell_config="${scripts_dir}/500_global_zsh_prompt.sh"
        if [[ ! -f "$shell_config" || "$OVERWRITE_EXISTING" == true ]]; then
            cat > "$shell_config" << EOF
#!/usr/bin/env zsh
# Zsh prompt configuration

# Load colors
autoload -U colors && colors

# Git status function
git_prompt_info() {
    if ! command -v git >/dev/null 2>&1; then
        return
    fi

    local branch
    branch=\$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)
    
    if [[ -n "\$branch" ]]; then
        echo " %F{green}(\$branch)%f"
    fi
}

# Set prompt
PROMPT=\$'\n%F{green}%n@%m%f %F{blue}%~%f\$(git_prompt_info)\n%# '
EOF
            chmod 700 "$shell_config"
        fi
    fi

    # Hostname-specific configuration
    local hostname_config="${scripts_dir}/700_${hostname}_common_settings.sh"
    if [[ ! -f "$hostname_config" || "$OVERWRITE_EXISTING" == true ]]; then
        cat > "$hostname_config" << EOF
#!/usr/bin/env bash
# Hostname-specific configuration for ${hostname}

# Include required functions
include_function common is_macos
include_function common is_linux

# Add machine-specific configurations
# Uncomment and modify as needed

# Example: Set up specific paths
# include_function path add_to_path
# add_to_path "/path/specific/to/${hostname}"

# Example: Set environment variables
# export MACHINE_SPECIFIC_VAR="value"

# Example: Define machine-specific aliases
# alias backup="rsync -avz ~/Documents user@backup-server:/backups/${hostname}"
EOF
        chmod 700 "$hostname_config"
    fi
}

# Update shell RC files
UpdateRCFiles() {
    local shell_type="$1"
    local rc_file=""

    InfoMessage "Updating shell RC configuration..."

    # Determine appropriate RC file
    if [[ "$shell_type" == "bash" ]]; then
        rc_file="${HOME}/.bashrc"
    elif [[ "$shell_type" == "zsh" ]]; then
        rc_file="${HOME}/.zshrc"
    else
        ErrorMessage "Unsupported shell type: $shell_type"
        return 1
    }

    # Check if rcForge is already sourced
    if grep -q "rcforge.sh" "$rc_file" 2>/dev/null; then
        InfoMessage "rcForge already configured in $rc_file"
        return 0
    fi

    # Backup existing RC file
    if [[ -f "$rc_file" ]]; then
        cp "$rc_file" "${rc_file}.bak"
        WarningMessage "Backed up existing $rc_file to ${rc_file}.bak"
    fi

    # Add rcForge source line
    echo "" >> "$rc_file"
    echo "# Source rcForge configuration" >> "$rc_file"
    echo "if [[ -f \"\$HOME/.config/rcforge/rcforge.sh\" ]]; then" >> "$rc_file"
    echo "  source \"\$HOME/.config/rcforge/rcforge.sh\"" >> "$rc_file"
    echo "fi" >> "$rc_file"

    # Set correct permissions
    chmod 600 "$rc_file"

    SuccessMessage "Updated $rc_file to source rcForge"
}

# Interactive configuration mode
InteractiveSetup() {
    if [[ "$INTERACTIVE_MODE" == false ]]; then
        return 0
    fi

    SectionHeader "rcForge Interactive Setup"

    # Confirm shell type
    local confirm_shell
    read -r -p "Configure for current shell (${TARGET_SHELL})? [Y/n]: " confirm_shell
    if [[ -n "$confirm_shell" && ! "$confirm_shell" =~ ^[Yy]$ ]]; then
        read -r -p "Enter shell type (bash/zsh): " TARGET_SHELL
        ValidateShellType "$TARGET_SHELL" || return 1
    fi

    # Confirm minimal setup
    if [[ "$MINIMAL_SETUP" == false ]]; then
        read -r -p "Perform minimal setup? [y/N]: " minimal_choice
        if [[ "$minimal_choice" =~ ^[Yy]$ ]]; then
            MINIMAL_SETUP=true
        fi
    fi

    # Confirm overwrite
    if [[ "$OVERWRITE_EXISTING" == false ]]; then
        read -r -p "Overwrite existing configurations? [y/N]: " overwrite_choice
        if [[ "$overwrite_choice" =~ ^[Yy]$ ]]; then
            OVERWRITE_EXISTING=true
        fi
    fi
}

# Main script execution
Main() {
    # Parse command-line arguments
    ParseArguments "$@"

    # Display header
    SectionHeader "${gc_app_name} Setup Utility"

    # Interactive configuration
    InteractiveSetup

    # Create base directory structure
    CreateDirectoryStructure

    # Create sample configurations
    CreateSampleConfigurations \
        "$gc_default_scripts_dir" \
        "$TARGET_SHELL" \
        "$HOSTNAME"

    # Update shell RC file
    UpdateRCFiles "$TARGET_SHELL"

    # Final success message
    echo ""
    SuccessMessage "${gc_app_name} setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Restart your shell or run: source ~/.${TARGET_SHELL}rc"
    echo "2. Customize configurations in: ${gc_config_base_dir}/scripts/"
}

# Entry point - execute only if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    Main "$@"
fi
