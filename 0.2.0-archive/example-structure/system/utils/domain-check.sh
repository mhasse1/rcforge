#!/usr/bin/env bash
# DomainCheck.sh - Domain name availability checking utility
# Category: web
# Author: Mark Hasse
# Date: 2025-03-31
#
# This file provides functions for checking domain name availability
# using WHOIS lookups across multiple TLDs.

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

# Default available TLDs
export DEFAULT_TLDS=("com" "ai" "io" "app")

#--------------------------------------------------------------
# Domain Checking Functions
#--------------------------------------------------------------

# Function: DomainCheck
# Description: Checks the availability of one or more domain names
# Usage: DomainCheck [--tlds=com,ai,io,app] [--all-tlds] <domain1> [domain2] ...
# Arguments:
#   --tlds=LIST    Comma-separated list of TLDs to check (default: com,ai,io,app)
#   --all-tlds     Check each domain with all TLDs (otherwise checks domain as provided)
#   <domains>      One or more domain names to check
# Returns: 
#   0 on success
#   1 if invalid arguments
#   2 if whois command not available
DomainCheck() {
  # Default list of TLDs to check
  local tlds=("${DEFAULT_TLDS[@]}")
  local domains=()
  local check_all_tlds=false

  # Validate whois command availability
  if ! command -v whois > /dev/null 2>&1; then
    echo "ERROR: whois command not available - cannot check domain availability" >&2
    return 2
  fi

  # Parse arguments
  for arg in "$@"; do
    # Check for TLD specification
    if [[ "$arg" == "--tlds="* ]]; then
      # Reset the default TLDs and use the provided ones
      IFS=',' read -r -a tlds <<< "${arg#--tlds=}"
    elif [[ "$arg" == "--all-tlds" ]]; then
      check_all_tlds=true
    else
      # Otherwise it's a domain to check
      domains+=("$arg")
    fi
  done

  # Check if any domains were provided
  if [[ ${#domains[@]} -eq 0 ]]; then
    # Display usage information
    cat << EOF
Usage: DomainCheck [--tlds=com,ai,io,app] [--all-tlds] <domain1> [domain2] ...

Options:
  --tlds=LIST    Comma-separated list of TLDs to check (default: com,ai,io,app)
  --all-tlds     Check each domain with all TLDs (otherwise checks domain as provided)

Examples:
  DomainCheck example
  DomainCheck --tlds=com,net,org example
  DomainCheck --all-tlds mydomain yourdomain
EOF
    return 1
  fi

  # Initialize counters for the summary
  local total_checked=0
  local total_available=0
  local available_domains=()

  # Process each domain
  for base_domain in "${domains[@]}"; do
    local domain="$base_domain"

    # Clean up domain (remove protocol, www, and any existing TLD)
    domain=$(echo "$domain" | sed -E 's|https?://||' | sed 's/^www\.//' | sed -E 's/\.[a-zA-Z][a-zA-Z]+$//')

    if [[ "$check_all_tlds" == "true" ]]; then
      # Check each TLD for this domain
      for tld in "${tlds[@]}"; do
        CheckSingleDomain "$domain" "$tld" total_checked total_available available_domains
      done
    else
      # Check the domain as provided (add .com if no TLD present)
      local full_domain="$base_domain"
      if ! [[ $base_domain =~ \.[a-zA-Z][a-zA-Z]+ ]]; then
        full_domain="${base_domain}.com"
      fi

      # Extract the base and TLD
      local base="${full_domain%.*}"
      local tld="${full_domain##*.}"
      
      CheckSingleDomain "$base" "$tld" total_checked total_available available_domains
    fi
  done

  # Print summary
  PrintDomainSummary "$total_checked" "$total_available" "${available_domains[@]}"
  
  return 0
}

# Function: CheckSingleDomain
# Description: Checks a single domain's availability
# Usage: CheckSingleDomain base_domain tld total_checked_var total_available_var available_domains_var
# Arguments:
#   $1 - Base domain name (without TLD)
#   $2 - TLD to check
#   $3 - Name of variable to update with total checked count
#   $4 - Name of variable to update with total available count
#   $5 - Name of array variable to update with available domains
# Returns: None (updates passed variables)
CheckSingleDomain() {
  local base_domain="$1"
  local tld="$2"
  local -n checked_count="$3"
  local -n available_count="$4"
  local -n available_list="$5"
  
  local full_domain="${base_domain}.${tld}"
  
  echo "-------------------------------"
  echo "Checking availability for: $full_domain"

  # Use whois to check domain availability
  local whois_result
  whois_result=$(whois "$full_domain" 2>/dev/null)
  checked_count=$((checked_count + 1))

  # Common patterns that indicate domain availability
  if echo "$whois_result" | grep -i "No match for" > /dev/null ||
     echo "$whois_result" | grep -i "NOT FOUND" > /dev/null ||
     echo "$whois_result" | grep -i "No entries found" > /dev/null ||
     echo "$whois_result" | grep -i "Domain not found" > /dev/null; then
    echo "✅ Domain $full_domain appears to be AVAILABLE"
    available_count=$((available_count + 1))
    available_list+=("$full_domain")
  else
    echo "❌ Domain $full_domain appears to be TAKEN"
    # Show registration date if available
    local reg_date
    reg_date=$(echo "$whois_result" | grep -i "Creation Date\|created\|Registry" | head -1)
    if [[ -n "$reg_date" ]]; then
      echo "   Registration info: $reg_date"
    fi
  fi
}

# Function: PrintDomainSummary
# Description: Prints a summary of domain checking results
# Usage: PrintDomainSummary total_checked total_available available_domain1 [available_domain2 ...]
# Arguments:
#   $1 - Total number of domains checked
#   $2 - Total number of available domains
#   $3+ - Available domains (if any)
# Returns: None (prints summary to stdout)
PrintDomainSummary() {
  local total_checked="$1"
  local total_available="$2"
  shift 2
  local available_domains=("$@")
  
  # Summary message when finished
  echo "-------------------------------"
  echo "🎯 Domain Check Summary:"
  echo "🔍 Checked: $total_checked domains"
  echo "✅ Available: $total_available domains"
  echo "❌ Taken: $((total_checked - total_available)) domains"

  # Show available domains if any
  if [[ $total_available -gt 0 ]]; then
    echo ""
    echo "Available domains:"
    for available in "${available_domains[@]}"; do
      echo "   $available"
    done
  fi

  # Add a fun message based on results
  if [[ $total_available -eq 0 ]]; then
    echo "😢 Tough luck! All domains are taken. Time to get more creative?"
  elif [[ $total_available -eq $total_checked ]]; then
    echo "🎉 Jackpot! All domains are available. Quick, grab them before someone else does!"
  else
    echo "🙂 You've got options! Some domains are available for registration."
  fi
}

# Export all functions
export -f DomainCheck
export -f CheckSingleDomain
export -f PrintDomainSummary
# EOF
