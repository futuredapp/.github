#!/bin/bash
set -e

TAG="$VERSION_TAG"

if [[ "$TAG" =~ ^([0-9]+\.[0-9]+\.[0-9]+)(-([0-9]+))?$ ]]; then
  echo "version_number=${BASH_REMATCH[1]}" >> "$GITHUB_OUTPUT"
  if [[ -n "${BASH_REMATCH[3]}" ]]; then
    echo "build_number=${BASH_REMATCH[3]}" >> "$GITHUB_OUTPUT"
  fi
else
  echo "::error::Tag '$TAG' does not match expected format 'x.y.z' or 'x.y.z-k' (where k is an integer build number)"
  exit 1
fi
