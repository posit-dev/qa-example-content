#!/bin/bash

# Script to fetch the latest Ubuntu Noble Workbench URL from the Posit downloads endpoint

set -e

JSON_ENDPOINT="https://posit.co/wp-content/uploads/downloads.json"

# Fetch the JSON and extract the noble URL
NOBLE_URL=$(curl -s "$JSON_ENDPOINT" | jq -r '.rstudio.pro.stable.server.installer.noble.url')

if [ -z "$NOBLE_URL" ] || [ "$NOBLE_URL" = "null" ]; then
    echo "❌ ERROR: Failed to fetch the latest Noble URL from $JSON_ENDPOINT" >&2
    exit 1
fi

# Return the URL (useful when called from other scripts)
echo "$NOBLE_URL"
