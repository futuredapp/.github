#!/bin/bash
# Validates that all futuredapp/.github refs match the expected version.
# Exits 0 if all match, 1 if any mismatch.
#
# Usage: .github/scripts/validate-action-refs.sh <version>
# Example: .github/scripts/validate-action-refs.sh 2.3.0

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 2.3.0"
    exit 1
fi

EXPECTED_VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mismatched=()

while IFS= read -r file; do
    while IFS= read -r line; do
        ref=$(echo "$line" | grep -oE 'futuredapp/\.github/.+@[^ "]+' | head -1)
        mismatched+=("  ${file#"$SCRIPT_DIR"/../}: $ref")
    done < <(grep 'futuredapp/\.github/' "$file" | grep -v "@${EXPECTED_VERSION}")
done < <("$SCRIPT_DIR/find-action-refs.sh")

if [ ${#mismatched[@]} -gt 0 ]; then
    echo "Action refs not bumped to @${EXPECTED_VERSION}. Run: .github/scripts/bump-action-refs.sh ${EXPECTED_VERSION}"
    echo ""
    echo "Mismatched refs:"
    printf '%s\n' "${mismatched[@]}"
    exit 1
fi

echo "All action refs match @${EXPECTED_VERSION}"
