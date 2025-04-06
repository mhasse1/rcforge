#!/usr/bin/env bash
# rc-websiteup - Check if a website is available and responsive

# Help function
print_help() {
  cat << EOF
Usage: rc-websiteup <domain_or_url>

Checks if a website is available and responsive.
Supports both domain names and full URLs.

Options:
  -h, --help    Show this help message

Examples:
  rc-websiteup example.com
  rc-websiteup https://google.com
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

# Process URL step by step
url="$1"

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
http_code=$(grep -i "^HTTP/" "$temp_file" | tail -n 1 | awk '{print $2}')

if [[ -z "$http_code" ]]; then
  http_code="0"
fi

# Check for redirects
redirect_url=$(grep -i "^location:" "$temp_file" | tail -n 1 | awk '{print $2}' | tr -d '\r')

# Interpret status code
if [[ "$http_code" = "0" ]]; then
  echo "❌ Could not connect to $url (connection error)"
  exit 1
elif [[ "$http_code" -ge 200 && "$http_code" -lt 400 ]]; then
  if [[ -n "$redirect_url" ]]; then
    echo "✅ $url is UP (Status: $http_code, redirects to $redirect_url)"
  else
    echo "✅ $url is UP (Status: $http_code)"
  fi
else
  echo "❌ $url appears to be DOWN (Status: $http_code)"
  exit 1
fi

# Always show DNS lookup
domain=$(echo "$url" | sed -E 's|https?://||' | cut -d'/' -f1)

echo
echo "DNS lookup:"
if command -v dig > /dev/null 2>&1; then
  dig +short "$domain"
elif command -v host > /dev/null 2>&1; then
  host "$domain" | grep 'has address'
else
  nslookup "$domain" 2>/dev/null | grep 'Address' | grep -v '#' | cut -d' ' -f2
fi

exit 0
