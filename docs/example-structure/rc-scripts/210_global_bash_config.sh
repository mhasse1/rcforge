#!/bin/bash
##########################################
# 100_bash_settings.sh - Bash-specific settings
##########################################
# Enable vi mode
set -o vi

# Bash options
shopt -s histappend     # Append to history file, don't overwrite
shopt -s checkwinsize   # Check window size after each command
shopt -s globstar 2>/dev/null || true  # "**" pattern in globbing
shopt -s cdspell 2>/dev/null || true   # Autocorrect typos in cd

# History settings
export HISTSIZE=1500
export HISTFILESIZE=2000
export HISTCONTROL=ignoreboth  # Ignore duplicates and lines starting with space
