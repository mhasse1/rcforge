#!/usr/bin/env bash
# rc-dnslookup - Perform DNS lookup for a domain

# Help function
print_help() {
  cat << EOF
Usage: rc-dnslookup <domain>

Performs a DNS lookup for the specified domain using available system tools.

Examples:
  rc-dnslookup example.com
  rc-dnslookup google.com
EOF
}

# Validate input
if [[ $# -eq 0 ]]; then
  print_help
  exit 1
fi

# Handle help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  print_help
  exit 0
fi

# DNS Lookup function
perform_dns_lookup() {
  local domain="$1"

  # Try different DNS lookup tools depending on availability
  if command -v dig > /dev/null 2>&1; then
    dig +short "$domain"
  elif command -v host > /dev/null 2>&1; then
    host "$domain" | grep 'has address'
  else
    nslookup "$domain" 2>/dev/null | grep 'Address' | grep -v '#' | cut -d' ' -f2
  fi
}

# Execute DNS lookup
perform_dns_lookup "$1"
