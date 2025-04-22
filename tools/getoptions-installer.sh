#!/usr/bin/env bash
# getoptions-install.sh - Install/update getoptions library
# Author: rcForge Team
# Date: 2025-04-22
# Version: 0.5.0
# Category: system/utility
# RC Summary: Install or update the getoptions library for rcForge
# Description: Downloads the latest version of getoptions from GitHub
#              and integrates it with rcForge library structure.

# Source necessary libraries
source "${RCFORGE_LIB:-$HOME/.local/share/rcforge/system/lib}/utility-functions.sh"

# Set strict error handling
set -o nounset
set -o pipefail

# Global constants
[ -v gc_version ]  || readonly gc_version="${RCFORGE_VERSION:-0.5.0}"
[ -v gc_app_name ] || readonly gc_app_name="${RCFORGE_APP_NAME:-rcForge}"
readonly UTILITY_NAME="getoptions-install"
readonly GETOPTIONS_REPO="https://raw.githubusercontent.com/ko1nksm/getoptions/v3.3.0"
readonly GETOPTIONS_DEST="${RCFORGE_LIB:-${XDG_DATA_HOME:-$HOME/.local/share}/rcforge/system/lib}/getoptions.sh"
readonly TEMP_DIR="/tmp/rcforge_getoptions_install_$$"

# ============================================================================
# Function: ShowHelp
# Description: Display detailed help information for this utility.
# Usage: ShowHelp
# Arguments: None
# Returns: None. Exits with status 0.
# ============================================================================
ShowHelp() {
    echo "${UTILITY_NAME} - ${gc_app_name} Utility (v${gc_version})"
    echo ""
    echo "Description:"
    echo "  Installs or updates the getoptions library for rcForge."
    echo "  This downloads the latest stable version from GitHub"
    echo "  and integrates it with the rcForge library structure."
    echo ""
    echo "Usage:"
    echo "  rc ${UTILITY_NAME} [options]"
    echo "  $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  --force, -f         Force update even if already installed"
    echo "  --branch=BRANCH     Specify a different branch/tag (default: v3.3.0)"
    echo "  --help, -h          Show this help message"
    echo "  --summary           Show a one-line description (for rc help)"
    echo "  --version           Show version information"
    echo ""
    echo "Examples:"
    echo "  rc ${UTILITY_NAME}              # Install standard version"
    echo "  rc ${UTILITY_NAME} --force      # Force reinstallation"
    echo "  rc ${UTILITY_NAME} --branch=master  # Install from master branch"
    exit 0
}

# ============================================================================
# Function: main
# Description: Main execution logic for getoptions installation.
# Usage: main "$@"
# Arguments: Command-line arguments
# Returns: 0 on success, non-zero on error.
# ============================================================================
main() {
    local force_update=false
    local branch="v3.3.0"
    
    # Process command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                ShowHelp
                ;;
            --summary)
                ExtractSummary "$0"
                exit $?
                ;;
            --version)
                echo "${UTILITY_NAME} (${gc_app_name}) v${gc_version}"
                exit 0
                ;;
            -f|--force)
                force_update=true
                shift
                ;;
            --branch=*)
                branch="${1#*=}"
                shift
                ;;
            --branch)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    ErrorMessage "--branch requires a value"
                    return 1
                fi
                branch="$2"
                shift 2
                ;;
            *)
                ErrorMessage "Unknown option: $1"
                echo "Use --help for usage information."
                return 1
                ;;
        esac
    done

    # Check if already installed (unless force update)
    if [[ -f "$GETOPTIONS_DEST" && "$force_update" == "false" ]]; then
        InfoMessage "getoptions is already installed at:"
        InfoMessage "  $GETOPTIONS_DEST"
        InfoMessage "Use --force to reinstall/update."
        return 0
    fi
    
    # Create temp directory
    SectionHeader "Installing getoptions"
    InfoMessage "Creating temporary directory..."
    mkdir -p "$TEMP_DIR" || {
        ErrorMessage "Failed to create temporary directory: $TEMP_DIR"
        return 1
    }
    
    # Download files
    InfoMessage "Downloading getoptions from GitHub (branch: $branch)..."
    local repo_url="${GETOPTIONS_REPO/v3.3.0/$branch}"
    
    # Download main file
    if ! curl --fail --silent --location --output "$TEMP_DIR/getoptions.sh" "$repo_url/getoptions.sh"; then
        ErrorMessage "Failed to download getoptions.sh from GitHub"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Create directory if needed
    mkdir -p "$(dirname "$GETOPTIONS_DEST")" || {
        ErrorMessage "Failed to create destination directory: $(dirname "$GETOPTIONS_DEST")"
        rm -rf "$TEMP_DIR"
        return 1
    }
    
    # Combine with rcForge wrapper
    InfoMessage "Integrating with rcForge..."
    {
        # Create header
        cat <<EOF
#!/usr/bin/env bash
# getoptions.sh - Elegant option parser for shell scripts
# Author: rcForge Team (Adaptation of ko1nksm/getoptions)
# Date: $(date +%Y-%m-%d)
# Version: ${gc_version}
# Category: system/library
# Description: A POSIX-compliant command-line option parser for shell scripts,
#              adapted and integrated for rcForge. Based on ko1nksm/getoptions.

# --- Include Guard ---
if [[ -n "\${_RCFORGE_GETOPTIONS_SH_SOURCED:-}" ]]; then
    return 0
fi
_RCFORGE_GETOPTIONS_SH_SOURCED=true

# ============================================================================
# getoptions Implementation
# Source: https://github.com/ko1nksm/getoptions
# ============================================================================

EOF
        
        # Add original getoptions implementation
        sed -n '/^getoptions()/,/^}$/p' < "$TEMP_DIR/getoptions.sh"
        
        # Add rcForge wrapper functions
        cat <<EOF

# ============================================================================
# rcForge Wrapper and Utilities
# ============================================================================

# Function: GetoInit
# Description: Initialize getoptions with default rcForge settings
# Usage: GetoInit variable_name_prefix
GetoInit() {
    local prefix="\${1:-opts}"
    
    # Create standard parser with the given prefix
    getoptions "\${prefix}_define" \\
        --prefix="\$prefix" \\
        --name="\${UTILITY_NAME:-\${0##*/}}" \\
        --error-handler="\${prefix}_error"
    
    # Define standard error handler
    eval "\${prefix}_error() {
        local message=\"\\\$1\"
        if command -v ErrorMessage >/dev/null 2>&1; then
            ErrorMessage \"\\\$message\"
        else
            echo \"ERROR: \\\$message\" >&2
        fi
        \${prefix}_usage
        exit 1
    }"
    
    # Define help generator
    eval "\${prefix}_usage() {
        if [ -n \"\\\$\${prefix}_help\" ]; then
            if command -v InfoMessage >/dev/null 2>&1; then
                InfoMessage \"Usage: \\\$\${prefix}_name [\\\$\${prefix}_flags]\"
                echo \"\"
                InfoMessage \"Options:\"
                echo \"\\\$\${prefix}_help\" | sed 's/^/  /'
            else
                echo \"Usage: \\\$\${prefix}_name [\\\$\${prefix}_flags]\"
                echo \"\"
                echo \"Options:\"
                echo \"\\\$\${prefix}_help\" | sed 's/^/  /'
            fi
        fi
    }"
}

# Function: GetoFlag
# Description: Add a flag option (boolean)
# Usage: GetoFlag variable_name_prefix option_char option_name help_text [default_value]
GetoFlag() {
    local prefix="\$1"
    local opt_char="\$2"
    local opt_name="\$3"
    local help_text="\$4"
    local default="\${5:-false}"
    
    # Define this flag in getoptions format
    eval "\${prefix}_define() {
        _getopt_params=\"\\\$_getopt_params
        \${opt_name}() { 
            _\${prefix}_\${opt_name}=true
        }\"
        
        # Add to help text
        _getopt_help=\"\\\$_getopt_help
        -\${opt_char}, --\${opt_name}  \${help_text}\"
        
        # Add to flags list
        _getopt_flags=\"\\\$_getopt_flags -\${opt_char}|--\${opt_name}\"
    }"
    
    # Set default value
    eval "_\${prefix}_\${opt_name}=\${default}"
}

# Function: GetoParam
# Description: Add a parameter option (with value)
# Usage: GetoParam variable_name_prefix option_char option_name help_text [default_value]
GetoParam() {
    local prefix="\$1"
    local opt_char="\$2"
    local opt_name="\$3"
    local help_text="\$4"
    local default="\${5:-}"
    
    # Define this parameter in getoptions format
    eval "\${prefix}_define() {
        _getopt_params=\"\\\$_getopt_params
        \${opt_name}() { 
            _\${prefix}_\${opt_name}=\\\\\"\\\\\$1\\\\\"
        }\"
        
        # Add to help text
        _getopt_help=\"\\\$_getopt_help
        -\${opt_char}, --\${opt_name}=VALUE  \${help_text}\"
        
        # Add to flags list
        _getopt_flags=\"\\\$_getopt_flags -\${opt_char}|--\${opt_name}\"
    }"
    
    # Set default value if provided
    if [ -n "\$default" ]; then
        eval "_\${prefix}_\${opt_name}=\"\${default}\""
    fi
}

# Function: GetoAddHelp
# Description: Add standard help option
# Usage: GetoAddHelp variable_name_prefix
GetoAddHelp() {
    local prefix="\$1"
    
    # Define standard help option
    eval "\${prefix}_define() {
        _getopt_params=\"\\\$_getopt_params
        help() { 
            \${prefix}_usage
            exit 0
        }\"
        
        # Add to help text
        _getopt_help=\"\\\$_getopt_help
        -h, --help  Show this help message\"
        
        # Add to flags list
        _getopt_flags=\"\\\$_getopt_flags -h|--help\"
    }"
}

# Function: GetoParse
# Description: Parse command line arguments
# Usage: GetoParse variable_name_prefix "\$@"
GetoParse() {
    local prefix="\$1"
    shift
    
    # Run the parser
    eval "\${prefix}_parser" '"\$@"'
    
    # Return status
    return \$?
}

# EOF
EOF
    } > "$GETOPTIONS_DEST"
    
    # Set permissions
    chmod 700 "$GETOPTIONS_DEST" || {
        ErrorMessage "Failed to set permissions on: $GETOPTIONS_DEST"
        rm -rf "$TEMP_DIR"
        return 1
    }
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    SuccessMessage "getoptions installed successfully to:"
    SuccessMessage "  $GETOPTIONS_DEST"
    InfoMessage "Now you can use getoptions in your utilities by sourcing this file"
    
    return 0
}

# Execute main function if run directly or via rc command
if IsExecutedDirectly || [[ "$0" == *"rc"* ]]; then
    main "$@"
    exit $? # Exit with status from main
fi

# EOF
