#!/bin/bash
set -e

# If SECRET_PROPERTIES is not set, there is nothing to do.
if [ -z "$SECRET_PROPERTIES" ]; then
  echo "SECRET_PROPERTIES is empty, skipping."
  exit 0
fi

# Convert the required keys into a space-separated list (POSIX shell does not support arrays)
REQUIRED_KEYS_ARRAY=$(echo "$REQUIRED_KEYS" | tr ',' ' ')

# Temporary file to track which keys have been found
FOUND_KEYS=$(mktemp)

# Process each line of the secret properties
echo "$SECRET_PROPERTIES" | while IFS= read -r line; do
  if [ -n "$line" ]; then
    # Extract the key and value from the line
    KEY=$(echo "$line" | cut -d '=' -f 1 | xargs)
    VALUE=$(echo "$line" | cut -d '=' -f 2- | xargs)

    # Check if the value is empty
    if [ -z "$VALUE" ]; then
      echo "Error: Key '$KEY' is required but has an empty value." >&2
      exit 1
    fi

    # Record the found key in the temporary file
    echo "$KEY" >> "$FOUND_KEYS"

    # Encode the value in Base64 and append it to the xcconfig file
    ENCODED_VALUE=$(echo -n "$VALUE" | base64)
    echo "$KEY = $ENCODED_VALUE" >> "$XCCONFIG_PATH"
  fi
done

# Check if all required keys were found
for REQUIRED_KEY in $REQUIRED_KEYS_ARRAY; do
  if ! grep -qw "$REQUIRED_KEY" "$FOUND_KEYS"; then
    echo "Error: Required key '$REQUIRED_KEY' is missing from SECRET_PROPERTIES." >&2
    rm -f "$FOUND_KEYS" # Clean up the temporary file
    exit 1
  fi
done

# Clean up the temporary file
rm -f "$FOUND_KEYS"

echo "Updated xcconfig file at $XCCONFIG_PATH"