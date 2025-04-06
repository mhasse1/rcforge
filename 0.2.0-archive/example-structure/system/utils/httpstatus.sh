#!/usr/bin/env bash
# rc-httpstatus - Get HTTP status code for a URL

# Help function
print_help() {
  cat << EOF
Usage: rc-httpstatus <url>

Retrieves the HTTP status code for the specified URL.

Options:
  -h, --help    Show this help message

Examples:
  rc-httpstatus example.com
  rc-httpstatus https://google.com
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

# Prepare URL
url="$1"

# Add protocol if needed
if ! echo "$url" | grep -q "^http"; then
  url="https://${url}"
fi

# Get HTTP status code
status=$(curl -s -o /dev/null -w "%{http_code}" -L "$url")

echo "$status"
