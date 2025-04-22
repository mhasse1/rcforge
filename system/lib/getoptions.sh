#!/usr/bin/env bash
# getoptions.sh - Elegant option parser for shell scripts
# Author: rcForge Team (Adaptation of ko1nksm/getoptions)
# Date: 2025-04-22
# Version: 0.5.0
# Category: system/library
# Description: A POSIX-compliant command-line option parser for shell scripts,
#              adapted and integrated for rcForge. Based on ko1nksm/getoptions.

# --- Include Guard ---
if [[ -n "${_RCFORGE_GETOPTIONS_SH_SOURCED:-}" ]]; then
    return 0
fi
_RCFORGE_GETOPTIONS_SH_SOURCED=true

# ============================================================================
# getoptions Implementation
# Source: https://github.com/ko1nksm/getoptions
# ============================================================================

# Core getoptions implementation
# Keeping original license and attribution
# MIT License - Copyright (c) 2017-2024 Koichi Nakashima
getoptions() {
    _getopt_cmd=$1
    shift
    
    # Initialize variables
    _getopt_params=''
    _getopt_help=''
    _getopt_flags=''
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --prefix=*) _getopt_prefix=${1#*=} ;;
            --name=*) _getopt_name=${1#*=} ;;
            --error-handler=*) _getopt_error_handler=${1#*=} ;;
            --) shift; break ;;
            -?*) echo "getoptions: unknown option: $1" >&2; return 1 ;;
            *) break ;;
        esac
        shift
    done
    
    # Define the parser and default handlers
    eval "
        _getopt_prefix=\"\${_getopt_prefix:-_getopt}\"
        _getopt_name=\"\${_getopt_name:-\$0}\"
        _getopt_error_handler=\"\${_getopt_error_handler:-:}\"
        
        ${_getopt_prefix}_params='${_getopt_params}'
        ${_getopt_prefix}_help='${_getopt_help}'
        ${_getopt_prefix}_flags='${_getopt_flags}'
        
        # Handle option parsing
        ${_getopt_prefix}_parser() {
            OPTIND=1
            while getoptions_getopt \"\$@\"; do
                case \"\$OPTNAME\" in
                    '?') eval \"\$${_getopt_prefix}_error_handler\" \"\$OPTARG\"; return \$? ;;
                    :) eval \"\$${_getopt_prefix}_error_handler\" \"option requires an argument: \$OPTARG\"; return \$? ;;
                    *) eval \"\$OPTNAME() { echo \\\"\$OPTNAME \$OPTARG\\\"; }; \$OPTNAME \\\"\$OPTARG\\\"\" ;;
                esac
            done
            eval \"set -- \$OPTARG\"
            return 0
        }
        
        # Internal getoptions
        getoptions_getopt() {
            [ \$# -gt 0 ] || return 1
            
            OPTIND=\$((\${OPTIND:-1} + 1))
            [ \$OPTIND -gt \$# ] && return 1
            
            OPTARG=\${!OPTIND}
            [ \"\$OPTARG\" = \"--\" ] && {
                OPTARG=\$((\$OPTIND + 1))
                OPTARG=\"\${@:\$OPTARG}\"
                return 1
            }
            
            case \$OPTARG in
                --?*=*) OPTNAME=\${OPTARG%%=*}; OPTNAME=\${OPTNAME#--}; OPTARG=\${OPTARG#*=} ;;
                --?*) OPTNAME=\${OPTARG#--}; OPTARG='' ;;
                -*) OPTNAME=\${OPTARG#-}; OPTARG='' ;;
                *) OPTARG=\$((\$OPTIND + 1)); OPTARG=\"\${@:\$OPTARG}\"; return 1 ;;
            esac
            
            return 0
        }
    "
    
    # Process subcommands and define options
    while [ $# -gt 0 ]; do
        case $1 in
            --) shift; break ;;
            *) eval "$_getopt_cmd \"\$@\""; break ;;
        esac
    done
    
    return 0
}

# ============================================================================
# rcForge Wrapper and Utilities
# ============================================================================

# Function: GetoInit
# Description: Initialize getoptions with default rcForge settings
# Usage: GetoInit variable_name_prefix
GetoInit() {
    local prefix="${1:-opts}"
    
    # Create standard parser with the given prefix
    getoptions "${prefix}_define" \
        --prefix="$prefix" \
        --name="${UTILITY_NAME:-${0##*/}}" \
        --error-handler="${prefix}_error"
    
    # Define standard error handler
    eval "${prefix}_error() {
        local message=\"\$1\"
        if command -v ErrorMessage >/dev/null 2>&1; then
            ErrorMessage \"\$message\"
        else
            echo \"ERROR: \$message\" >&2
        fi
        ${prefix}_usage
        exit 1
    }"
    
    # Define help generator
    eval "${prefix}_usage() {
        if [ -n \"\$${prefix}_help\" ]; then
            if command -v InfoMessage >/dev/null 2>&1; then
                InfoMessage \"Usage: \$${prefix}_name [\$${prefix}_flags]\"
                echo \"\"
                InfoMessage \"Options:\"
                echo \"\$${prefix}_help\" | sed 's/^/  /'
            else
                echo \"Usage: \$${prefix}_name [\$${prefix}_flags]\"
                echo \"\"
                echo \"Options:\"
                echo \"\$${prefix}_help\" | sed 's/^/  /'
            fi
        fi
    }"
}

# Function: GetoFlag
# Description: Add a flag option (boolean)
# Usage: GetoFlag variable_name_prefix option_char option_name help_text [default_value]
GetoFlag() {
    local prefix="$1"
    local opt_char="$2"
    local opt_name="$3"
    local help_text="$4"
    local default="${5:-false}"
    
    # Define this flag in getoptions format
    eval "${prefix}_define() {
        _getopt_params=\"\$_getopt_params
        ${opt_name}() { 
            _${prefix}_${opt_name}=true
        }\"
        
        # Add to help text
        _getopt_help=\"\$_getopt_help
        -${opt_char}, --${opt_name}  ${help_text}\"
        
        # Add to flags list
        _getopt_flags=\"\$_getopt_flags -${opt_char}|--${opt_name}\"
    }"
    
    # Set default value
    eval "_${prefix}_${opt_name}=${default}"
}

# Function: GetoParam
# Description: Add a parameter option (with value)
# Usage: GetoParam variable_name_prefix option_char option_name help_text [default_value]
GetoParam() {
    local prefix="$1"
    local opt_char="$2"
    local opt_name="$3"
    local help_text="$4"
    local default="${5:-}"
    
    # Define this parameter in getoptions format
    eval "${prefix}_define() {
        _getopt_params=\"\$_getopt_params
        ${opt_name}() { 
            _${prefix}_${opt_name}=\\\"\\\$1\\\"
        }\"
        
        # Add to help text
        _getopt_help=\"\$_getopt_help
        -${opt_char}, --${opt_name}=VALUE  ${help_text}\"
        
        # Add to flags list
        _getopt_flags=\"\$_getopt_flags -${opt_char}|--${opt_name}\"
    }"
    
    # Set default value if provided
    if [ -n "$default" ]; then
        eval "_${prefix}_${opt_name}=\"${default}\""
    fi
}

# Function: GetoAddHelp
# Description: Add standard help option
# Usage: GetoAddHelp variable_name_prefix
GetoAddHelp() {
    local prefix="$1"
    
    # Define standard help option
    eval "${prefix}_define() {
        _getopt_params=\"\$_getopt_params
        help() { 
            ${prefix}_usage
            exit 0
        }\"
        
        # Add to help text
        _getopt_help=\"\$_getopt_help
        -h, --help  Show this help message\"
        
        # Add to flags list
        _getopt_flags=\"\$_getopt_flags -h|--help\"
    }"
}

# Function: GetoParse
# Description: Parse command line arguments
# Usage: GetoParse variable_name_prefix "$@"
GetoParse() {
    local prefix="$1"
    shift
    
    # Run the parser
    eval "${prefix}_parser" '"$@"'
    
    # Return status
    return $?
}

# EOF
