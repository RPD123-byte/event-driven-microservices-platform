#!/bin/bash

# Batch script to convert all JSON prompts to YAML format
# Usage: ./batch_convert_json_to_yaml.sh [directory]

set -e

# Use provided directory or current directory
SEARCH_DIR="${1:-.}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if convert script exists
if [[ "$0" == */* ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi
CONVERT_SCRIPT="$SCRIPT_DIR/convert_json_to_yaml.sh"
if [ ! -f "$CONVERT_SCRIPT" ]; then
    echo -e "${RED}Error: convert_json_to_yaml.sh not found at $CONVERT_SCRIPT${NC}"
    exit 1
fi

# Make sure convert script is executable
chmod +x "$CONVERT_SCRIPT"

# Find all prompt JSON files
echo "Searching for JSON prompt files in: $SEARCH_DIR"
JSON_FILES=$(find "$SEARCH_DIR" -name "prompt_*.json" -type f | grep -v "_wrapped.json" | sort)

if [ -z "$JSON_FILES" ]; then
    echo "No prompt JSON files found"
    exit 0
fi

# Count files
TOTAL_FILES=$(echo "$JSON_FILES" | wc -l | tr -d ' ')
echo "Found $TOTAL_FILES JSON files to convert"
echo "---"

# Convert each file
SUCCESS_COUNT=0
FAIL_COUNT=0

for JSON_FILE in $JSON_FILES; do
    # The convert script will automatically put it in .forge directory
    echo -n "Converting $(basename "$JSON_FILE")... "
    
    # Call convert script without output file (it will auto-generate in .forge)
    if "$CONVERT_SCRIPT" "$JSON_FILE" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}✗${NC}"
        ((FAIL_COUNT++))
    fi
done

# Summary
echo "---"
echo "Conversion complete:"
echo -e "${GREEN}Successful: $SUCCESS_COUNT${NC}"
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
fi

# Clean up any temporary wrapped files
find "$SEARCH_DIR" -name "*_wrapped.json" -type f -delete 2>/dev/null || true