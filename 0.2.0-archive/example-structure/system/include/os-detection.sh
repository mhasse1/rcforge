#!/usr/bin/env bash
# OsDetection.sh - Comprehensive OS detection capabilities
# Category: common
# Author: Mark Hasse
# Date: 2025-03-31
#
# This file provides a complete set of OS detection functions for use in
# scripts that need to perform platform-specific operations.

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Define cached variables to avoid repeated calls to external commands
export OS_NAME=""
export OS_RELEASE_ID=""
export OS_VERSION=""

# Function: DetectOsInfo
# Description: Detects and caches OS information
# Usage: DetectOsInfo
# Returns: None (sets environment variables)
DetectOsInfo() {
    # Get OS name if not already cached
    if [[ -z "$OS_NAME" ]]; then
        OS_NAME="$(uname -s)"
    fi
    
    # Get Linux distribution info if applicable
    if [[ "$OS_NAME" == "Linux" ]] && [[ -z "$OS_RELEASE_ID" ]]; then
        if [[ -f /etc/os-release ]]; then
            # Source the os-release file to get distribution information
            # shellcheck disable=SC1091
            source /etc/os-release
            OS_RELEASE_ID="${ID:-unknown}"
            OS_VERSION="${VERSION_ID:-unknown}"
        elif [[ -f /etc/lsb-release ]]; then
            # shellcheck disable=SC1091
            source /etc/lsb-release
            OS_RELEASE_ID="${DISTRIB_ID:-unknown}"
            OS_VERSION="${DISTRIB_RELEASE:-unknown}"
        else
            OS_RELEASE_ID="unknown"
            OS_VERSION="unknown"
        fi
    fi
}

# Call DetectOsInfo once when the file is sourced
DetectOsInfo

#--------------------------------------------------------------
# Major OS Family Detection Functions
#--------------------------------------------------------------

# Function: IsMacOS
# Description: Tests if the current system is running macOS/Darwin
# Usage: IsMacOS
# Returns: 0 if running on macOS, 1 otherwise
IsMacOS() {
    [[ "$OS_NAME" == "Darwin" ]]
    return $?
}

# Function: IsLinux
# Description: Tests if the current system is running Linux
# Usage: IsLinux
# Returns: 0 if running on Linux, 1 otherwise
IsLinux() {
    [[ "$OS_NAME" == "Linux" ]]
    return $?
}

# Function: IsWindows
# Description: Tests if the current system is running Windows (WSL, MSYS, or Cygwin)
# Usage: IsWindows
# Returns: 0 if running on Windows, 1 otherwise
IsWindows() {
    local uname_output
    uname_output="$(uname -a)"
    
    # Check for Windows Subsystem for Linux (WSL)
    if [[ "$uname_output" =~ [Mm]icrosoft ]] || [[ "$uname_output" =~ WSL ]]; then
        return 0
    fi
    
    # Check for MSYS, MINGW, or Cygwin
    if [[ "$OS_NAME" =~ MINGW ]] || [[ "$OS_NAME" =~ MSYS ]] || [[ "$OS_NAME" =~ CYGWIN ]]; then
        return 0
    fi
    
    # Not Windows
    return 1
}

# Function: IsBSD
# Description: Tests if the current system is running a BSD variant
# Usage: IsBSD
# Returns: 0 if running on BSD, 1 otherwise
IsBSD() {
    # Check for FreeBSD, OpenBSD, NetBSD, or DragonFly
    [[ "$OS_NAME" == "FreeBSD" ]] || 
    [[ "$OS_NAME" == "OpenBSD" ]] || 
    [[ "$OS_NAME" == "NetBSD" ]] || 
    [[ "$OS_NAME" == "DragonFly" ]]
    return $?
}

# Function: IsSolaris
# Description: Tests if the current system is running Solaris or illumos
# Usage: IsSolaris
# Returns: 0 if running on Solaris, 1 otherwise
IsSolaris() {
    [[ "$OS_NAME" == "SunOS" ]]
    return $?
}

#--------------------------------------------------------------
# Linux Distribution Detection Functions
#--------------------------------------------------------------

# Function: IsUbuntu
# Description: Tests if the current system is running Ubuntu Linux
# Usage: IsUbuntu
# Returns: 0 if running on Ubuntu, 1 otherwise
IsUbuntu() {
    # First check if we're on Linux
    if ! IsLinux; then
        return 1
    fi
    
    [[ "$OS_RELEASE_ID" == "ubuntu" ]]
    return $?
}

# Function: IsDebian
# Description: Tests if the current system is running Debian Linux
# Usage: IsDebian
# Returns: 0 if running on Debian, 1 otherwise
IsDebian() {
    # First check if we're on Linux
    if ! IsLinux; then
        return 1
    fi
    
    [[ "$OS_RELEASE_ID" == "debian" ]]
    return $?
}

# Function: IsFedora
# Description: Tests if the current system is running Fedora Linux
# Usage: IsFedora
# Returns: 0 if running on Fedora, 1 otherwise
IsFedora() {
    # First check if we're on Linux
    if ! IsLinux; then
        return 1
    fi
    
    [[ "$OS_RELEASE_ID" == "fedora" ]]
    return $?
}

# Function: IsCentOS
# Description: Tests if the current system is running CentOS Linux
# Usage: IsCentOS
# Returns: 0 if running on CentOS, 1 otherwise
IsCentOS() {
    # First check if we're on Linux
    if ! IsLinux; then
        return 1
    fi
    
    [[ "$OS_RELEASE_ID" == "centos" ]]
    return $?
}

# Function: IsRedHat
# Description: Tests if the current system is running Red Hat Enterprise Linux
# Usage: IsRedHat
# Returns: 0 if running on RHEL, 1 otherwise
IsRedHat() {
    # First check if we're on Linux
    if ! IsLinux; then
        return 1
    fi
    
    [[ "$OS_RELEASE_ID" == "rhel" ]]
    return $?
}

# Function: IsArch
# Description: Tests if the current system is running Arch Linux
# Usage: IsArch
# Returns: 0 if running on Arch, 1 otherwise
IsArch() {
    # First check if we're on Linux
    if ! IsLinux; then
        return 1
    fi
    
    [[ "$OS_RELEASE_ID" == "arch" ]]
    return $?
}

# Function: IsAlpine
# Description: Tests if the current system is running Alpine Linux
# Usage: IsAlpine
# Returns: 0 if running on Alpine, 1 otherwise
IsAlpine() {
    # First check if we're on Linux
    if ! IsLinux; then
        return 1
    fi
    
    [[ "$OS_RELEASE_ID" == "alpine" ]]
    return $?
}

# Function: IsSUSE
# Description: Tests if the current system is running SUSE Linux
# Usage: IsSUSE
# Returns: 0 if running on SUSE, 1 otherwise
IsSUSE() {
    # First check if we're on Linux
    if ! IsLinux; then
        return 1
    fi
    
    [[ "$OS_RELEASE_ID" == "suse" ]] || [[ "$OS_RELEASE_ID" == "opensuse" ]]
    return $?
}

#--------------------------------------------------------------
# BSD Variant Detection Functions
#--------------------------------------------------------------

# Function: IsFreeBSD
# Description: Tests if the current system is running FreeBSD
# Usage: IsFreeBSD
# Returns: 0 if running on FreeBSD, 1 otherwise
IsFreeBSD() {
    [[ "$OS_NAME" == "FreeBSD" ]]
    return $?
}

# Function: IsOpenBSD
# Description: Tests if the current system is running OpenBSD
# Usage: IsOpenBSD
# Returns: 0 if running on OpenBSD, 1 otherwise
IsOpenBSD() {
    [[ "$OS_NAME" == "OpenBSD" ]]
    return $?
}

# Function: IsNetBSD
# Description: Tests if the current system is running NetBSD
# Usage: IsNetBSD
# Returns: 0 if running on NetBSD, 1 otherwise
IsNetBSD() {
    [[ "$OS_NAME" == "NetBSD" ]]
    return $?
}

#--------------------------------------------------------------
# Utility Functions
#--------------------------------------------------------------

# Function: GetOsName
# Description: Gets the name of the operating system
# Usage: GetOsName
# Returns: Echoes the name of the OS
GetOsName() {
    if IsMacOS; then
        echo "macOS"
    elif IsLinux; then
        if [[ -n "$OS_RELEASE_ID" && "$OS_RELEASE_ID" != "unknown" ]]; then
            echo "$OS_RELEASE_ID"
        else
            echo "Linux"
        fi
    elif IsWindows; then
        echo "Windows"
    elif IsBSD; then
        echo "$OS_NAME"
    elif IsSolaris; then
        echo "Solaris"
    else
        echo "$OS_NAME"
    fi
}

# Function: GetOsVersion
# Description: Gets the version of the operating system
# Usage: GetOsVersion
# Returns: Echoes the version of the OS
GetOsVersion() {
    if IsMacOS; then
        sw_vers -productVersion 2>/dev/null || echo "Unknown"
    elif IsLinux; then
        if [[ -n "$OS_VERSION" && "$OS_VERSION" != "unknown" ]]; then
            echo "$OS_VERSION"
        else
            uname -r
        fi
    elif IsBSD || IsSolaris; then
        uname -r
    else
        echo "Unknown"
    fi
}

# Function: GetSystemInfo
# Description: Gets detailed information about the system
# Usage: GetSystemInfo [--json]
# Arguments:
#   --json - Output in JSON format
# Returns: Echoes system information
GetSystemInfo() {
    local format="${1:-text}"
    
    if [[ "$format" == "--json" ]]; then
        # JSON output format
        cat << EOF
{
  "os": "$(GetOsName)",
  "version": "$(GetOsVersion)",
  "kernel": "$(uname -r)",
  "architecture": "$(uname -m)",
  "hostname": "$(hostname)"
}
EOF
    else
        # Plain text output format
        cat << EOF
Operating System: $(GetOsName)
Version: $(GetOsVersion)
Kernel: $(uname -r)
Architecture: $(uname -m)
Hostname: $(hostname)
EOF
    fi
}

# Export all functions
export -f DetectOsInfo
export -f IsMacOS
export -f IsLinux
export -f IsWindows
export -f IsBSD
export -f IsSolaris
export -f IsUbuntu
export -f IsDebian
export -f IsFedora
export -f IsCentOS
export -f IsRedHat
export -f IsArch
export -f IsAlpine
export -f IsSUSE
export -f IsFreeBSD
export -f IsOpenBSD
export -f IsNetBSD
export -f GetOsName
export -f GetOsVersion
export -f GetSystemInfo
# EOF
