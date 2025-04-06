#!/bin/bash
# validate-deb.sh - Validate a Debian package before installation
# Author: Mark Hasse
# Date: 2025-03-29

set -e  # Exit on error

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color

# Check for package parameter
if [[ $# -lt 1 ]]; then
    echo -e "${RED}Error: Please specify a .deb package to validate.${RESET}"
    echo "Usage: $0 package.deb"
    exit 1
fi

PACKAGE_PATH="$1"

# Check if the file exists and is a .deb file
if [[ ! -f "$PACKAGE_PATH" ]]; then
    echo -e "${RED}Error: File not found: $PACKAGE_PATH${RESET}"
    exit 1
fi

if [[ "$PACKAGE_PATH" != *.deb ]]; then
    echo -e "${RED}Error: Not a Debian package file: $PACKAGE_PATH${RESET}"
    echo "Please specify a .deb file."
    exit 1
fi

# Header
echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│ Debian Package Validator                             │${RESET}"
echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
echo ""

echo -e "${CYAN}Package to validate: ${YELLOW}$PACKAGE_PATH${RESET}"
echo ""

# Create temporary directory for extraction
TEMP_DIR=$(mktemp -d)
echo -e "${CYAN}Using temporary directory: ${YELLOW}$TEMP_DIR${RESET}"

# Function to clean up temporary files on exit
cleanup() {
    echo -e "${CYAN}Cleaning up temporary files...${RESET}"
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Step 1: Basic package information
echo -e "${CYAN}Step 1: Basic package information${RESET}"
dpkg-deb --info "$PACKAGE_PATH"
echo -e "${GREEN}✓ Package info check complete${RESET}"
echo ""

# Step 2: Extract maintainer scripts
echo -e "${CYAN}Step 2: Extracting and checking maintainer scripts${RESET}"
dpkg-deb -e "$PACKAGE_PATH" "$TEMP_DIR/DEBIAN"

# Check each script for syntax errors
SCRIPT_ERRORS=0
SCRIPT_WARNING=0

for script in postinst prerm preinst postrm; do
    if [ -f "$TEMP_DIR/DEBIAN/$script" ]; then
        echo -e "${YELLOW}Checking $script script:${RESET}"
        
        # Check permissions
        if [ ! -x "$TEMP_DIR/DEBIAN/$script" ]; then
            echo -e "${YELLOW}Warning: $script is not executable${RESET}"
            SCRIPT_WARNING=$((SCRIPT_WARNING+1))
        fi
        
        # Check if it's a shell script
        SHEBANG=$(head -n 1 "$TEMP_DIR/DEBIAN/$script")
        if [[ "$SHEBANG" != "#!/bin/sh" && "$SHEBANG" != "#!/bin/bash" ]]; then
            echo -e "${YELLOW}Warning: $script does not have a proper shebang ($SHEBANG)${RESET}"
            SCRIPT_WARNING=$((SCRIPT_WARNING+1))
        fi
        
        # Check script syntax
        bash -n "$TEMP_DIR/DEBIAN/$script"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ $script syntax is valid${RESET}"
            
            # Count lines and check for common issues
            LINE_COUNT=$(wc -l < "$TEMP_DIR/DEBIAN/$script")
            echo "   - Script has $LINE_COUNT lines"
            
            # Check for common issues
            grep -q "set -e" "$TEMP_DIR/DEBIAN/$script" || echo -e "${YELLOW}   - Warning: No 'set -e' found${RESET}"
            grep -q "exit 0" "$TEMP_DIR/DEBIAN/$script" || echo -e "${YELLOW}   - Warning: No explicit 'exit 0' at end${RESET}"
            
            # Check for dangerous commands
            if grep -q "rm -rf /" "$TEMP_DIR/DEBIAN/$script"; then
                echo -e "${RED}   - DANGER: Script contains 'rm -rf /' command!${RESET}"
                SCRIPT_ERRORS=$((SCRIPT_ERRORS+1))
            fi
        else
            echo -e "${RED}× $script contains syntax errors${RESET}"
            SCRIPT_ERRORS=$((SCRIPT_ERRORS+1))
        fi
        
        echo ""
    fi
done

# Step 3: Check file list
echo -e "${CYAN}Step 3: Checking package contents${RESET}"
dpkg-deb -c "$PACKAGE_PATH"
echo -e "${GREEN}✓ Package contents check complete${RESET}"
echo ""

# Step 4: Extract and check some critical files
echo -e "${CYAN}Step 4: Checking critical files${RESET}"
mkdir -p "$TEMP_DIR/extract"
dpkg-deb -x "$PACKAGE_PATH" "$TEMP_DIR/extract"

# Check for common files
CRITICAL_ERRORS=0
for path in usr/share/rcforge/rcforge.sh usr/bin/rcforge; do
    if [ -f "$TEMP_DIR/extract/$path" ]; then
        echo -e "${GREEN}✓ Found $path${RESET}"
        
        # Check if file is executable
        if [ ! -x "$TEMP_DIR/extract/$path" ]; then
            echo -e "${YELLOW}   - Warning: File is not executable${RESET}"
        fi
        
        # If it's a script, check syntax
        if [[ "$path" == *.sh || "$path" == *bin/* ]]; then
            bash -n "$TEMP_DIR/extract/$path" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}   - Syntax is valid${RESET}"
            else
                echo -e "${RED}   - File contains syntax errors${RESET}"
                CRITICAL_ERRORS=$((CRITICAL_ERRORS+1))
            fi
        fi
    else
        echo -e "${RED}× Missing critical file: $path${RESET}"
        CRITICAL_ERRORS=$((CRITICAL_ERRORS+1))
    fi
done

echo ""

# Step 5: Run lintian if available
echo -e "${CYAN}Step 5: Running lintian checks${RESET}"
if command -v lintian >/dev/null 2>&1; then
    LINTIAN_OUTPUT=$(lintian "$PACKAGE_PATH" 2>&1)
    LINTIAN_CODE=$?
    
    if [ $LINTIAN_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ Lintian passed with no errors${RESET}"
    else
        echo -e "${YELLOW}Lintian reported issues:${RESET}"
        echo "$LINTIAN_OUTPUT"
    fi
else
    echo -e "${YELLOW}Lintian not found. Install with: sudo apt install lintian${RESET}"
fi
echo ""

# Step 6: Summary
echo -e "${BLUE}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│ Validation Summary                                   │${RESET}"
echo -e "${BLUE}└──────────────────────────────────────────────────────┘${RESET}"
echo ""

if [ $SCRIPT_ERRORS -gt 0 ] || [ $CRITICAL_ERRORS -gt 0 ]; then
    echo -e "${RED}× Package validation FAILED${RESET}"
    echo -e "${RED}  - $SCRIPT_ERRORS maintainer script errors${RESET}"
    echo -e "${RED}  - $CRITICAL_ERRORS critical file errors${RESET}"
    echo -e "${YELLOW}  - $SCRIPT_WARNING maintainer script warnings${RESET}"
    echo ""
    echo -e "${RED}Package may not install or function correctly.${RESET}"
    
    exit 1
else
    if [ $SCRIPT_WARNING -gt 0 ]; then
        echo -e "${YELLOW}⚠ Package validation PASSED WITH WARNINGS${RESET}"
        echo -e "${YELLOW}  - $SCRIPT_WARNING maintainer script warnings${RESET}"
        echo ""
        echo -e "${YELLOW}Package may install but could have issues.${RESET}"
    else
        echo -e "${GREEN}✓ Package validation PASSED${RESET}"
        echo -e "${GREEN}  - No errors or warnings detected${RESET}"
        echo ""
        echo -e "${GREEN}Package should install and function correctly.${RESET}"
    fi
    
    echo ""
    echo -e "${CYAN}You can now install the package with:${RESET}"
    echo "  sudo dpkg -i $PACKAGE_PATH"
    echo "  sudo apt install -f  # To resolve any dependencies"
    
    exit 0
fi
# EOF