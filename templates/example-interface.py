#!/usr/bin/env python3
# hello.py - Simple greeting utility in Python
# RC Summary: Displays a customizable greeting message (Python version)

import argparse
import sys
import os

def main():
    parser = argparse.ArgumentParser(description="Displays a customizable greeting message")
    parser.add_argument("name", nargs="?", default="Friend", help="Name to greet")
    parser.add_argument("--format", default="Hello, {name}!", help="Greeting format")
    parser.add_argument("--uppercase", "-u", action="store_true", help="Convert to uppercase")
    parser.add_argument("--summary", action="store_true", help="Show summary for rc help")
    parser.add_argument("--version", action="store_true", help="Show version information")
    
    args = parser.parse_args()
    
    # Handle special rc command flags
    if args.summary:
        print("Displays a customizable greeting message (Python version)")
        return 0
    if args.version:
        print(f"hello - rcForge Utility v0.4.1")
        return 0
        
    # Main functionality
    greeting = args.format.format(name=args.name)
    if args.uppercase:
        greeting = greeting.upper()
        
    print(greeting)
    return 0

if __name__ == "__main__":
    sys.exit(main())
