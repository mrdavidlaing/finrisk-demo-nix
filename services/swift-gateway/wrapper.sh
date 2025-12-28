#!/usr/bin/env bash
# Wrapper script for COBOL MT103 generator
# Converts JSON input to COBOL format and calls the compiled program

set -e

# Read JSON from stdin
JSON_INPUT=$(cat)

# Extract fields using jq or basic parsing
SENDER_ID=$(echo "$JSON_INPUT" | grep -o '"senderId"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -c 20)
RECIPIENT_ID=$(echo "$JSON_INPUT" | grep -o '"recipientId"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -c 20)
AMOUNT=$(echo "$JSON_INPUT" | grep -o '"amount"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*')
CURRENCY=$(echo "$JSON_INPUT" | grep -o '"currency"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -c 3)
REFERENCE="TRANSFERX-$(date +%s)"

# Format for COBOL (fixed-width)
printf "%-20s%-20s%015.2f%-3s%-35s" \
  "$SENDER_ID" \
  "$RECIPIENT_ID" \
  "$AMOUNT" \
  "${CURRENCY:-USD}" \
  "$REFERENCE" | mt103-generator



