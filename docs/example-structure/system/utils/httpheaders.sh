#!/usr/bin/env bash
# rc-httpheaders - Retrieve HTTP headers for a URL

# Help function
print_help() {
  cat << EOF
Usage: rc-httpheaders <url>

Retrieves and displays HTTP headers for the specified URL.

Options:
  -h, --help    Show this help message

Examples:
  rc-httpheaders example.com
  rc-httpheaders https://google.com
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

# Get HTTP headers
curl -s -I -L "$url"
