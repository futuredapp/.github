#!/bin/bash
set -e

TAG="$VERSION_TAG"

if [[ "$TAG" =~ ^([0-9]+\.[0-9]+\.[0-9]+)(-.*)?$ ]]; then
  echo "version_number=${BASH_REMATCH[1]}" >> "$GITHUB_OUTPUT"
else
  echo "::error::Tag '$TAG' does not match expected format 'x.y.z' or 'x.y.z-*' (any suffix after - is ignored)"
  exit 1
fi
