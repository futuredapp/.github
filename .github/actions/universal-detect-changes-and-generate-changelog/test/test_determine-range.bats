#!/usr/bin/env bats

load 'test_helper'

@test "determine-range: skips build when no merge commits since last build" {
  export INPUT_DEBUG="false"
  export INPUT_FALLBACK_LOOKBACK="24 hours"
  create_mock_cache_file "valid-commit"
  
  # Mock git functions
  git() {
    case "$1" in
      "rev-parse")
        echo "current-head"
        ;;
      "cat-file")
        return 0  # Valid commit
        ;;
      "rev-list")
        echo "0"  # No merge commits
        ;;
    esac
  }
  export -f git
  
  run ../determine-range.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^build_should_skip=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "true" ]
  
  cleanup_mock_files
}

@test "determine-range: proceeds with build when merge commits exist since last build" {
  export INPUT_DEBUG="false"
  export INPUT_FALLBACK_LOOKBACK="24 hours"
  create_mock_cache_file "valid-commit"
  mock_git
  
  # Mock git rev-list to return merge commits
  git() {
    case "$1" in
      "rev-parse")
        echo "current-head"
        ;;
      "cat-file")
        return 0  # Valid commit
        ;;
      "rev-list")
        echo "2"  # 2 merge commits
        ;;
    esac
  }
  export -f git
  
  run ../determine-range.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^build_should_skip=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "false" ]
  [ "$(grep '^from_commit=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "valid-commit" ]
  [ "$(grep '^to_commit=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "current-head" ]
  
  cleanup_mock_files
}

@test "determine-range: handles invalid previous commit by using fallback" {
  export INPUT_DEBUG="false"
  export INPUT_FALLBACK_LOOKBACK="24 hours"
  create_mock_cache_file "invalid-commit"
  mock_git
  
  # Mock git to return invalid commit and find fallback
  git() {
    case "$1" in
      "rev-parse")
        echo "current-head"
        ;;
      "cat-file")
        return 1  # Invalid commit
        ;;
      "rev-list")
        if [[ "$*" == *"--after=24 hours"* ]]; then
          echo "oldest-merge-commit"
        else
          echo "0"
        fi
        ;;
    esac
  }
  export -f git
  
  run ../determine-range.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^build_should_skip=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "false" ]
  [ "$(grep '^from_commit=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "oldest-merge-commit^" ]
  
  cleanup_mock_files
}

@test "determine-range: skips build when no previous commit and no fallback commits" {
  export INPUT_DEBUG="false"
  export INPUT_FALLBACK_LOOKBACK="24 hours"
  mock_git
  
  # Mock git to find no fallback commits
  git() {
    case "$1" in
      "rev-parse")
        echo "current-head"
        ;;
      "rev-list")
        echo ""  # No commits found
        ;;
    esac
  }
  export -f git
  
  run ../determine-range.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^build_should_skip=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "true" ]
  
  cleanup_mock_files
}

@test "determine-range: handles empty cache file" {
  export INPUT_DEBUG="false"
  export INPUT_FALLBACK_LOOKBACK="24 hours"
  create_mock_cache_file ""  # Empty file
  
  git() {
    case "$1" in
      "rev-parse")
        echo "current-head"
        ;;
      "rev-list")
        echo "oldest-merge-commit"
        ;;
    esac
  }
  export -f git
  
  run ../determine-range.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^build_should_skip=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "false" ]
  [ "$(grep '^from_commit=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "oldest-merge-commit^" ]
  
  cleanup_mock_files
}

@test "determine-range: handles missing cache file" {
  export INPUT_DEBUG="false"
  export INPUT_FALLBACK_LOOKBACK="24 hours"
  # No cache file created
  
  git() {
    case "$1" in
      "rev-parse")
        echo "current-head"
        ;;
      "rev-list")
        echo "oldest-merge-commit"
        ;;
    esac
  }
  export -f git
  
  run ../determine-range.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^build_should_skip=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "false" ]
  [ "$(grep '^from_commit=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "oldest-merge-commit^" ]
  
  cleanup_mock_files
}

@test "determine-range: handles git rev-parse failure" {
  export INPUT_DEBUG="false"
  export INPUT_FALLBACK_LOOKBACK="24 hours"
  create_mock_cache_file "valid-commit"
  
  git() {
    case "$1" in
      "rev-parse")
        return 1  # Git rev-parse fails
        ;;
    esac
  }
  export -f git
  
  run ../determine-range.sh
  
  [ "$status" -ne 0 ]  # Should fail due to git rev-parse error
  cleanup_mock_files
}

@test "determine-range: handles different fallback time windows" {
  export INPUT_DEBUG="false"
  export INPUT_FALLBACK_LOOKBACK="1 hour"
  create_mock_cache_file "invalid-commit"
  
  git() {
    case "$1" in
      "rev-parse")
        echo "current-head"
        ;;
      "cat-file")
        return 1  # Invalid commit
        ;;
      "rev-list")
        if [[ "$*" == *"--after=1 hour"* ]]; then
          echo "recent-merge-commit"
        else
          echo "0"
        fi
        ;;
    esac
  }
  export -f git
  
  run ../determine-range.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^build_should_skip=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "false" ]
  [ "$(grep '^from_commit=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "recent-merge-commit^" ]
  
  cleanup_mock_files
}

@test "determine-range: debug output when enabled" {
  export INPUT_DEBUG="true"
  export INPUT_FALLBACK_LOOKBACK="7 days"
  create_mock_cache_file "debug-commit"
  mock_git
  
  git() {
    case "$1" in
      "rev-parse")
        echo "debug-head"
        ;;
      "cat-file")
        return 0
        ;;
      "rev-list")
        echo "1"
        ;;
    esac
  }
  export -f git
  
  run ../determine-range.sh
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "\[DEBUG\] Previous built commit SHA from cache: 'debug-commit'"
  echo "$output" | grep -q "\[DEBUG\] Using git range: 'debug-commit..HEAD'"
  echo "$output" | grep -q "\[DEBUG\] New merge commits found since last build"
  
  cleanup_mock_files
}
