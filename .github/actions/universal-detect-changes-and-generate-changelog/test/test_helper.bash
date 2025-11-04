#!/usr/bin/env bash

# Test helper functions for BATS tests

# Create a temporary GITHUB_OUTPUT file for testing
setup() {
  export GITHUB_OUTPUT=$(mktemp)
}

# Clean up temporary files
teardown() {
  rm -f "$GITHUB_OUTPUT"
}

# Mock git commands for testing
mock_git() {
  # Create a mock git function that can be overridden in individual tests
  git() {
    case "$1" in
      "rev-parse")
        echo "abc123def456"
        ;;
      "cat-file")
        # Mock successful cat-file for valid commits
        if [[ "$2" == "-e" && "$3" == "valid-commit" ]]; then
          return 0
        else
          return 1
        fi
        ;;
      "rev-list")
        # Mock git rev-list for merge commits
        if [[ "$*" == *"--merges"* ]]; then
          case "$*" in
            *"valid-commit..HEAD"*)
              echo "2"  # 2 merge commits
              ;;
            *"invalid-commit..HEAD"*)
              echo "0"  # No merge commits
              ;;
            *"--after=24 hours"*)
              echo "oldest-merge-commit"
              ;;
            *)
              echo ""  # No commits found
              ;;
          esac
        fi
        ;;
      "log")
        # Mock git log for changelog generation
        if [[ "$*" == *"--merges"* && "$*" == *"--pretty=format:%b"* ]]; then
          echo "Merge commit message 1"
          echo "Merge commit message 2"
        elif [[ "$*" == *"--merges"* && "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature-1' into main"
          echo "Merge pull request #123 from feature-2"
        fi
        ;;
    esac
  }
  export -f git
}

# Create a mock latest_builded_commit.txt file
create_mock_cache_file() {
  local commit_sha="$1"
  echo "$commit_sha" > latest_builded_commit.txt
}

# Clean up mock files
cleanup_mock_files() {
  rm -f latest_builded_commit.txt
}
