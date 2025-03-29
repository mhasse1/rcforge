#!/bin/bash
# rcforge-functions.md
# This is a reference document showing all available functions in the rcForge system
# This is not meant to be executed, but to serve as documentation

# SHELL DETECTION FUNCTIONS
#----------------------------------------------------------------------------------------

# Detects the current shell and sets shell_name variable
detect_shell() {
  if [[ -n "$ZSH_VERSION" ]]; then
    shell_name="zsh"
  elif [[ -n "$BASH_VERSION" ]]; then
    shell_name="bash"
  else
    # Fallback to checking $SHELL
    shell_name=$(basename "$SHELL")
  fi
  export shell_name
}

# Returns true if current shell is bash
shell_is_bash() {
  [[ "$shell_name" == "bash" ]]
}

# Returns true if current shell is zsh
shell_is_zsh() {
  [[ "$shell_name" == "zsh" ]]
}

# Returns true if the command exists in the path
cmd_exists() {
  which $1 > /dev/null 2>&1
  [[ $? -eq 0 ]]
}

# Displays shell detection information if debugging is enabled
debug_shell_detection() {
  debug_echo "Detected shell: $shell_name"
  debug_echo "Shell environment details:"
  debug_echo "  BASH_VERSION: ${BASH_VERSION:-not set}"
  debug_echo "  ZSH_VERSION: ${ZSH_VERSION:-not set}"
  debug_echo "  SHELL: ${SHELL:-not set}"
}

# FILE SOURCING FUNCTIONS
#----------------------------------------------------------------------------------------

# Source a single file if it exists and is readable with timing information
source_file() {
  local file="$1"
  local desc="${2:-file}"
  local start_time=$(date +%s.%N)  # Get start time with nanosecond precision

  if [[ -f "$file" && -r "$file" ]]; then
    debug_echo "Loading $desc: $file"
    # shellcheck disable=SC1090
    source "$file"
    local end_time=$(date +%s.%N)
    local elapsed=$(echo "$end_time - $start_time" | bc)
    debug_echo "Loaded $desc: $file in $elapsed seconds"
    return 0
  else
    debug_echo "Skipping $desc (not found or not readable): $file"
    return 1
  fi
}

# Source multiple files matching a pattern with timing information
source_files() {
  local dir="$1"
  local pattern="$2"
  local desc="${3:-files}"
  local exclude="$4"
  local total_start=$(date +%s.%N)

  if [[ ! -d "$dir" ]]; then
    debug_echo "Directory not found: $dir"
    return 0
  fi

  debug_echo "Loading $desc from $dir matching $pattern"

  # Use find to get matching files, sorted
  for file in $(find "$dir" -maxdepth 1 -name "$pattern" -type f | sort); do
    if [[ -n "$exclude" && "$file" == "$exclude" ]]; then
      debug_echo "Skipping excluded file: $file"
      continue
    fi

    source_file "$file" "$desc"
  done

  local total_end=$(date +%s.%N)
  local total_elapsed=$(echo "$total_end - $total_start" | bc)
  debug_echo "Total time for loading $desc from $dir: $total_elapsed seconds"
}

# DEBUG AND WARNING FUNCTIONS
#----------------------------------------------------------------------------------------

# Toggle debug tracing on/off
toggle_debug_trace() {
  if [[ -n "$SHELL_DEBUG" ]]; then
    if [[ -n "$1" && "$1" = "on" ]]; then
      set -x
    else
      set +x
    fi
  fi
}

# Outputs a debug message if SHELL_DEBUG is set
debug_echo() {
  if [[ -n "$SHELL_DEBUG" ]]; then
    echo "DEBUG: $*"
  fi
}

# Outputs a warning message with visual emphasis
warn_echo() {
  echo
  echo "██╗    ██╗ █████╗ ██████╗ ███╗   ██╗██╗███╗   ██╗ ██████╗ "
  echo "██║    ██║██╔══██╗██╔══██╗████╗  ██║██║████╗  ██║██╔════╝ "
  echo "██║ █╗ ██║███████║██████╔╝██╔██╗ ██║██║██╔██╗ ██║██║  ███╗"
  echo "██║███╗██║██╔══██║██╔══██╗██║╚██╗██║██║██║╚██╗██║██║   ██║"
  echo "╚███╔███╔╝██║  ██║██║  ██║██║ ╚████║██║██║ ╚████║╚██████╔╝"
  echo " ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝ "
  echo
  echo "WARNING: $*"
  echo
}

# OS DETECTION FUNCTIONS
#----------------------------------------------------------------------------------------

# Returns true if running on macOS
is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

# Returns true if running on Linux
is_linux() {
  [[ "$(uname -s)" == "Linux" ]]
}

# Returns true if running on Windows (WSL or Git Bash)
is_windows() {
  [[ "$(uname -s)" == *"MINGW"* ]] || [[ "$(uname -r)" == *"Microsoft"* ]]
}

# CHECKSUM CALCULATIONS
#----------------------------------------------------------------------------------------

# Calculate the checksum of a file using the appropriate command for the OS
calculate_checksum() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "NONE"
    return 1
  fi

  if is_macos; then
    md5 -q "$file" 2>/dev/null
  elif is_linux || is_windows; then
    md5sum "$file" 2>/dev/null | awk '{ print $1 }'
  else
    # Fallback - try md5sum and if that fails, try md5
    md5sum "$file" 2>/dev/null | awk '{ print $1 }' || md5 -q "$file" 2>/dev/null || echo "UNKNOWN"
  fi
}

# Verify checksums for RC files
verify_checksum() {
  local rc_file="$1"
  local sum_file="$2"
  local rc_name="$3"

  # Skip if the RC file doesn't exist
  if [[ ! -f "$rc_file" ]]; then
    debug_echo "RC file not found: $rc_file"
    return 0
  fi

  # Get stored checksum if it exists, or create it
  if [[ -f "$sum_file" ]]; then
    stored_sum=$(cat "$sum_file")
  else
    # Create initial checksum file
    current_sum=$(calculate_checksum "$rc_file")
    echo "$current_sum" > "$sum_file"
    debug_echo "Created initial checksum for $rc_name: $current_sum"
    return 0
  fi

  # Get current checksum
  current_sum=$(calculate_checksum "$rc_file")
  debug_echo "Current checksum for $rc_name: $current_sum"
  debug_echo "Stored checksum for $rc_name: $stored_sum"

  # Compare checksums
  if [[ "$stored_sum" != "$current_sum" ]]; then
    # This part creates a visual warning and offers to update the checksum
    # Implementation details omitted for brevity
    return 1
  fi

  # Return 0 to indicate successful check (no mismatch)
  return 0
}

# UTILITY FUNCTIONS
#----------------------------------------------------------------------------------------

# Show the current PATH in a readable format
show_path() {
  echo "Current PATH:"
  echo "$PATH" | tr ':' '\n' | nl
}

# Add a directory to PATH if it exists and isn't already there
add_to_path() {
  local new_path="$1"

  if [[ -d "$new_path" && ":$PATH:" != *":$new_path:"* ]]; then
    export PATH="$new_path:$PATH"
    return 0
  fi
  return 1
}

# Append a directory to PATH if it exists and isn't already there
append_to_path() {
  local new_path="$1"

  if [[ -d "$new_path" && ":$PATH:" != *":$new_path:"* ]]; then
    export PATH="$PATH:$new_path"
    return 0
  fi
  return 1
}
