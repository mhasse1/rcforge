#!/usr/bin/env bash
# rc-domaincheck - Check domain availability for registration

# Help function
print_help() {
  cat << EOF
Usage: rc-domaincheck <domain>

Checks if a domain is available for registration using whois.

Options:
  -h, --help    Show this help message

Examples:
  rc-domaincheck example.com
  rc-domaincheck myuniquedomain
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

# Check if whois command is available
if ! command -v whois > /dev/null 2>&1; then
  echo "ERROR: whois command not available - cannot check domain availability" >&2
  exit 1
fi

# Clean up domain (remove protocol and www if present)
domain=$(echo "$1" | sed -E 's|https?://||' | sed 's/^www\.//')

# Add .com if no TLD is present
if ! [[ $domain =~ \.[a-zA-Z][a-zA-Z]+ ]]; then
  domain="${domain}.com"
fi

echo "Checking availability for: $domain"

# Use whois to check domain availability
whois_result=$(whois "$domain" 2>/dev/null)

if echo "$whois_result" | grep -i "No match for" > /dev/null ||
   echo "$whois_result" | grep -i "NOT FOUND" > /dev/null ||
   echo "$whois_result" | grep -i "No entries found" > /dev/null ||
   echo "$whois_result" | grep -i "Domain not found" > /dev/null; then
  echo "✅ Domain $domain appears to be AVAILABLE"
  exit 0
else
  echo "❌ Domain $domain appears to be TAKEN"

  # Show registration date if available
  reg_date=$(echo "$whois_result" | grep -i "Creation Date\|created\|Registry" | head -1)
  if [[ -n "$reg_date" ]]; then
    echo "Registration info: $reg_date"
  fi
  
  exit 1
fi
