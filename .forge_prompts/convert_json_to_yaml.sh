#!/bin/bash

# Script to convert workflow JSON files to YAML format
# Usage: ./convert_json_to_yaml.sh <input.json> [output.yaml]

set -e

# Check if input file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input.json> [output.yaml]"
    echo "Example: $0 prompt_001.json prompt_001.yaml"
    exit 1
fi

INPUT_FILE="$1"

# If output file is provided, use it. Otherwise, generate it in .forge directory
if [ -n "$2" ]; then
    OUTPUT_FILE="$2"
else
    # Convert .forge_prompts path to .forge path
    OUTPUT_FILE=$(echo "$INPUT_FILE" | sed 's/\.forge_prompts/.forge/' | sed 's/\.json$/.yaml/')
    
    # Create output directory if it doesn't exist
    OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
    mkdir -p "$OUTPUT_DIR"
fi

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first."
    exit 1
fi

# Create temporary file with wrapped JSON
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Wrap the JSON in the expected format
echo '{"workflow_json":' > "$TEMP_FILE"
cat "$INPUT_FILE" >> "$TEMP_FILE"
echo '}' >> "$TEMP_FILE"

# Call the API and extract YAML
echo "Converting $INPUT_FILE to YAML..."
RESPONSE=$(curl -X POST http://localhost:8000/api/workflows/json_to_yaml/ \
  -H "Content-Type: application/json" \
  -d @"$TEMP_FILE" \
  -s)

# Check if request was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to API"
    exit 1
fi

# Extract YAML from response
YAML_CONTENT=$(echo "$RESPONSE" | jq -r '.yaml // empty')
ERRORS=$(echo "$RESPONSE" | jq -r '.errors // empty')

# Check for errors
if [ -n "$ERRORS" ] && [ "$ERRORS" != "null" ]; then
    echo "Error converting JSON to YAML:"
    echo "$ERRORS"
    exit 1
fi

# Check if YAML content exists
if [ -z "$YAML_CONTENT" ] || [ "$YAML_CONTENT" = "null" ]; then
    echo "Error: No YAML content in response"
    echo "Full response: $RESPONSE"
    exit 1
fi

# Write YAML to output file
echo "$YAML_CONTENT" > "$OUTPUT_FILE"
echo "Successfully converted to: $OUTPUT_FILE"

# Show relative path if in .forge directory
if [[ "$OUTPUT_FILE" == *"/.forge/"* ]]; then
    RELATIVE_PATH=$(echo "$OUTPUT_FILE" | sed 's|.*/\.forge/|.forge/|')
    echo "Output location: $RELATIVE_PATH"
fi

# Optional: Display first few lines of output
echo -e "\nFirst 10 lines of YAML output:"
head -n 10 "$OUTPUT_FILE"