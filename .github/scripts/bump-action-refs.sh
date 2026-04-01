#!/bin/bash
# Updates all internal futuredapp/.github action/workflow refs to a specified version.
# Run this before creating a new release tag.
#
# Usage: .github/scripts/bump-action-refs.sh <version>
# Example: .github/scripts/bump-action-refs.sh 2.3.0

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 2.3.0"
    exit 1
fi

NEW_VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Cross-platform sed in-place
sedi() {
    if sed --version >/dev/null 2>&1; then
        sed -i -E "$@"  # GNU (Linux)
    else
        sed -i '' -E "$@"  # BSD (macOS)
    fi
}

updated=0

while IFS= read -r file; do
    sedi "s#(futuredapp/\.github/.+)@(main|[0-9]+\.[0-9]+\.[0-9]+)#\1@${NEW_VERSION}#g" "$file"
    echo "Updated: ${file#"$SCRIPT_DIR"/../}"
    updated=$((updated + 1))
done < <("$SCRIPT_DIR/find-action-refs.sh")

if [ "$updated" -eq 0 ]; then
    echo "No files with futuredapp/.github refs found."
else
    echo "Done. Updated $updated file(s) to @$NEW_VERSION."
fi
