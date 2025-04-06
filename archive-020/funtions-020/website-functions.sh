#!/usr/bin/env bash
# WebsiteUtils.sh - Website and domain utility functions
# Category: web
# Author: Mark Hasse
# Date: 2025-03-31
#
# This file provides a comprehensive set of functions for working with
# websites, domains, and DNS lookups.

# Set strict error handling
set -o nounset  # Treat unset variables as errors
 # set -o errexit  # Exit immediately if a command exits with a non-zero status

#--------------------------------------------------------------
# DNS and Domain Functions
#--------------------------------------------------------------

# Function: DnsLookup
# Description: Performs a DNS lookup using available system tools
# Usage: DnsLookup example.com
# Arguments:
#   $1 - Domain name to lookup
# Returns: 0 on success, outputs IP addresses to stdout
DnsLookup() {
  # Validate input
  if [[ $# -eq 0 ]]; then
    echo "ERROR: No domain specified for DNS lookup" >&2
    return 1
  fi

  local domain="$1"

  # Try different DNS lookup tools depending on availability
  if command -v dig > /dev/null 2>&1; then
    dig +short "$domain"
  elif command -v host > /dev/null 2>&1; then
    host "$domain" | grep 'has address'
  else
    nslookup "$domain" 2>/dev/null | grep 'Address' | grep -v '#' | cut -d' ' -f2
  fi

  return 0
}

# Function: IsWebsiteUp
# Description: Checks if a website is available and responsive
# Usage: IsWebsiteUp example.com
# Arguments:
#   $1 - URL or domain to check
# Returns: 0 if site is up, 1 if down or error
IsWebsiteUp() {
  # Validate input
  if [[ $# -eq 0 ]]; then
    echo "Usage: IsWebsiteUp <domain>" >&2
    return 1
  fi

  local url="$1"
  local temp_file=""

  # Process URL step by step
  # Remove whitespace
  url=$(echo "$url" | tr -d '[:space:]')

  # Add .com if needed - only if there's no period and not an IP address
  if ! echo "$url" | grep -q "\." && ! echo "$url" | grep -q "^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"; then
    url="${url}.com"
  fi

  # Add protocol if needed
  if ! echo "$url" | grep -q "^http"; then
    url="https://${url}"
  fi

  echo "Checking ${url}..."

  # Create temporary file for storing curl output
  temp_file=$(mktemp)

  # Ensure temp file gets cleaned up on exit
  trap 'rm -f "$temp_file"' EXIT

  # Run curl with explicit timeout and follow redirects
  curl -s -m 10 -I -L "$url" > "$temp_file"

  # Extract final status code from response
  local http_code
  http_code=$(grep -i "^HTTP/" "$temp_file" | tail -n 1 | awk '{print $2}')

  if [[ -z "$http_code" ]]; then
    http_code="0"
  fi

  # Check for redirects
  local redirect_url
  redirect_url=$(grep -i "^location:" "$temp_file" | tail -n 1 | awk '{print $2}' | tr -d '\r')

  # Interpret status code
  if [[ "$http_code" = "0" ]]; then
    echo "❌ Could not connect to $url (connection error)"

    # Try alternative protocol
    if echo "$url" | grep -q "^https://"; then
      echo "Trying HTTP instead of HTTPS..."
      local http_url
      http_url=$(echo "$url" | sed 's|^https://|http://|')

      # Clear and reuse temp file
      > "$temp_file"
      curl -s -m 10 -I -L "$http_url" > "$temp_file"

      local http_code
      http_code=$(grep -i "^HTTP/" "$temp_file" | tail -n 1 | awk '{print $2}')

      if [[ -n "$http_code" && "$http_code" -ge 200 && "$http_code" -lt 400 ]]; then
        echo "✅ $http_url is UP (Status: $http_code)"
      else
        echo "❌ $http_url is also DOWN (Status: $http_code)"

        # Add DNS lookup to help troubleshoot
        local domain
        domain=$(echo "$url" | sed -E 's|https?://||' | cut -d'/' -f1)

        echo
        echo "DNS lookup:"
        DnsLookup "$domain"

        return 1
      fi
    else
      # Add DNS lookup to help troubleshoot
      local domain
      domain=$(echo "$url" | sed -E 's|https?://||' | cut -d'/' -f1)

      echo
      echo "DNS lookup:"
      DnsLookup "$domain"

      return 1
    fi
  elif [[ "$http_code" -ge 200 && "$http_code" -lt 400 ]]; then
    if [[ -n "$redirect_url" ]]; then
      echo "✅ $url is UP (Status: $http_code, redirects to $redirect_url)"
    else
      echo "✅ $url is UP (Status: $http_code)"
    fi
  else
    echo "❌ $url appears to be DOWN (Status: $http_code)"

    # Add DNS lookup to help troubleshoot
    local domain
    domain=$(echo "$url" | sed -E 's|https?://||' | cut -d'/' -f1)

    echo
    echo "DNS lookup:"
    DnsLookup "$domain"

    return 1
  fi

  # Always show DNS lookup
  local domain
  domain=$(echo "$url" | sed -E 's|https?://||' | cut -d'/' -f1)

  echo
  echo "DNS lookup:"
  DnsLookup "$domain"

  return 0
}

# Function: CheckDomainAvailability
# Description: Checks if a domain is available for registration
# Usage: CheckDomainAvailability example.com
# Arguments:
#   $1 - Domain name to check
# Returns: 0 if domain is available, 1 if taken or error
CheckDomainAvailability() {
  # Validate input
  if [[ $# -eq 0 ]]; then
    echo "Usage: CheckDomainAvailability <domain>" >&2
    return 1
  fi

  local domain="$1"

  # Check if whois command is available
  if ! command -v whois > /dev/null 2>&1; then
    echo "ERROR: whois command not available - cannot check domain availability" >&2
    return 1
  fi

  # Clean up domain (remove protocol and www if present)
  domain=$(echo "$domain" | sed -E 's|https?://||' | sed 's/^www\.//')

  # Add .com if no TLD is present
  if ! [[ $domain =~ \.[a-zA-Z][a-zA-Z]+ ]]; then
    domain="${domain}.com"
  fi

  echo "Checking availability for: $domain"

  # Use whois to check domain availability
  local whois_result
  whois_result=$(whois "$domain" 2>/dev/null)

  if echo "$whois_result" | grep -i "No match for" > /dev/null ||
     echo "$whois_result" | grep -i "NOT FOUND" > /dev/null ||
     echo "$whois_result" | grep -i "No entries found" > /dev/null ||
     echo "$whois_result" | grep -i "Domain not found" > /dev/null; then
    echo "✅ Domain $domain appears to be AVAILABLE"
    return 0
  else
    echo "❌ Domain $domain appears to be TAKEN"

    # Show registration date if available
    local reg_date
    reg_date=$(echo "$whois_result" | grep -i "Creation Date\|created\|Registry" | head -1)
    if [[ -n "$reg_date" ]]; then
      echo "Registration info: $reg_date"
    fi

    return 1
  fi
}

# Function: GetHttpStatus
# Description: Gets the HTTP status code for a URL
# Usage: GetHttpStatus https://example.com
# Arguments:
#   $1 - URL to check
# Returns: Echoes the HTTP status code
GetHttpStatus() {
  # Validate input
  if [[ $# -eq 0 ]]; then
    echo "ERROR: No URL specified" >&2
    return 1
  fi

  local url="$1"

  # Add protocol if needed
  if ! echo "$url" | grep -q "^http"; then
    url="https://${url}"
  fi

  # Get HTTP status code
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" -L "$url")

  echo "$status"
  return 0
}

# Function: GetHttpHeaders
# Description: Gets the HTTP headers for a URL
# Usage: GetHttpHeaders https://example.com
# Arguments:
#   $1 - URL to check
# Returns: Echoes the HTTP headers
GetHttpHeaders() {
  # Validate input
  if [[ $# -eq 0 ]]; then
    echo "ERROR: No URL specified" >&2
    return 1
  fi

  local url="$1"

  # Add protocol if needed
  if ! echo "$url" | grep -q "^http"; then
    url="https://${url}"
  fi

  # Get HTTP headers
  curl -s -I -L "$url"
  return $?
}

# Export all functions
export -f DnsLookup
export -f IsWebsiteUp
export -f CheckDomainAvailability
export -f GetHttpStatus
export -f GetHttpHeaders
# EOF
