#!/usr/bin/env bats

load 'test_helper'

@test "generate-changelog: generates changelog for different commit range" {
  export FROM_COMMIT="commit1"
  export TO_COMMIT="commit2"
  export DEBUG="false"
  
  # Mock git log to return changelog and branch names
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Merge commit message 1"
          echo "Merge commit message 2"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature-1' into main"
          echo "Merge pull request #123 from feature-2"
        fi
        return 0
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  [ "$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "Merge commit message 1, Merge commit message 2" ]
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-1, feature-2" ]
}

@test "generate-changelog: handles same commit range using HEAD~1..HEAD" {
  export FROM_COMMIT="same-commit"
  export TO_COMMIT="same-commit"
  export DEBUG="false"
  mock_git
  
  # Mock git log for same commit case
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"HEAD~1..HEAD"* ]]; then
          if [[ "$*" == *"--pretty=format:%b"* ]]; then
            echo "Single merge commit message"
          elif [[ "$*" == *"--pretty=format:%s"* ]]; then
            echo "Merge branch 'single-feature' into main"
          fi
        fi
        return 0
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  [ "$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "Single merge commit message" ]
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "single-feature" ]
}

@test "generate-changelog: handles empty changelog" {
  export FROM_COMMIT="commit1"
  export TO_COMMIT="commit2"
  export DEBUG="false"
  mock_git
  
  # Mock git log to return empty output
  git() {
    case "$1" in
      "log")
        echo ""  # Empty output
        return 0
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  [ "$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "No changelog provided." ]
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "" ]
}

@test "generate-changelog: handles git log failure" {
  export FROM_COMMIT="commit1"
  export TO_COMMIT="commit2"
  export DEBUG="false"
  mock_git
  
  # Mock git log to fail
  git() {
    case "$1" in
      "log")
        echo "Git error message"
        return 1
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  [ "$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "Error generating changelog: command failed." ]
  echo "$output" | grep -q "##\[WARNING\] Git log command failed"
}

@test "generate-changelog: formats changelog with proper spacing" {
  export FROM_COMMIT="commit1"
  export TO_COMMIT="commit2"
  export DEBUG="false"
  mock_git
  
  # Mock git log with multiple lines
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Message 1"
          echo ""
          echo "Message 2"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature-1' into main"
          echo "Merge branch 'feature-2' into main"
        fi
        return 0
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  [ "$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "Message 1, Message 2" ]
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-1, feature-2" ]
}

@test "generate-changelog: handles whitespace-only changelog" {
  export FROM_COMMIT="commit1"
  export TO_COMMIT="commit2"
  export DEBUG="false"
  
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "   "  # Only whitespace
          echo ""
          echo "   "
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature' into main"
        fi
        return 0
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  [ "$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "No changelog provided." ]
}

@test "generate-changelog: handles newlines and special characters in changelog" {
  export FROM_COMMIT="commit1"
  export TO_COMMIT="commit2"
  export DEBUG="false"
  
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Message with newlines"
          echo "and special chars: @#$%"
          echo "and quotes: \"test\""
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature' into main"
        fi
        return 0
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  [ "$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "Message with newlines, and special chars: @#$%25, and quotes: \"test\"" ]
}

@test "generate-changelog: handles empty branch names" {
  export FROM_COMMIT="commit1"
  export TO_COMMIT="commit2"
  export DEBUG="false"
  
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Some changelog message"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo ""  # Empty branch names
        fi
        return 0
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  [ "$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "Some changelog message" ]
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "" ]
}

@test "generate-changelog: handles duplicate branch names" {
  export FROM_COMMIT="commit1"
  export TO_COMMIT="commit2"
  export DEBUG="false"
  
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Changelog message"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature-1' into main"
          echo "Merge branch 'feature-1' into main"  # Duplicate
          echo "Merge branch 'feature-2' into main"
          echo "Merge branch 'feature-1' into main"  # Another duplicate
        fi
        return 0
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-1, feature-2" ]
}

@test "generate-changelog: handles git log with different exit codes" {
  export FROM_COMMIT="commit1"
  export TO_COMMIT="commit2"
  export DEBUG="false"
  
  git() {
    case "$1" in
      "log")
        echo "Some error message"
        return 2  # Different exit code
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  [ "$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "Error generating changelog: command failed." ]
  echo "$output" | grep -q "##\[WARNING\] Git log command failed with exit code 2"
}

@test "generate-changelog: handles very long changelog messages" {
  export FROM_COMMIT="commit1"
  export TO_COMMIT="commit2"
  export DEBUG="false"
  
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "This is a very long changelog message that contains a lot of text and should be handled properly by the formatting function. It includes multiple lines and various characters."
          echo "Another long message with different content that also needs to be processed correctly."
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'long-feature-name' into main"
        fi
        return 0
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  local changelog=$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)
  echo "$changelog" | grep -q "This is a very long changelog message"
  echo "$changelog" | grep -q "Another long message"
}

@test "generate-changelog: debug output when enabled" {
  export FROM_COMMIT="debug-commit1"
  export TO_COMMIT="debug-commit2"
  export DEBUG="true"
  mock_git
  
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Debug message"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'debug-feature' into main"
        fi
        return 0
        ;;
    esac
  }
  export -f git
  
  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "\[DEBUG\] Generating changelog from debug-commit1 to debug-commit2"
  echo "$output" | grep -q "\[DEBUG\] Generated raw changelog:"
  echo "$output" | grep -q "\[DEBUG\] Generated raw branch names:"
  echo "$output" | grep -q "\[DEBUG\] Formatted changelog for output:"
  echo "$output" | grep -q "\[DEBUG\] Formatted branch names for output:"
}

@test "generate-changelog: handles quotes in merge commits without breaking outputs" {
  export FROM_COMMIT="commit1"
  export TO_COMMIT="commit2"
  export DEBUG="false"

  # Mock git to return messages and subjects containing both single and double quotes
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Fix: handle \"quoted\" values in output"
          echo "Ensure it's safe when there's a 'single quote' too"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature-quoted-\"name\"' into main"
          echo "Merge pull request #45 from feature-another'quoted'branch"
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]
  # Quotes should be preserved and outputs remain a single line key=value (no YAML/shell breakage)
  [ "$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "Fix: handle \"quoted\" values in output, Ensure it's safe when there's a 'single quote' too" ]
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-another'quoted'branch, feature-quoted-\"name\"" ]
}

@test "generate-changelog: handles raw double quotes via here-doc (no escaping in source)" {
  export FROM_COMMIT="commitA"
  export TO_COMMIT="commitB"
  export DEBUG="false"

  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          # Emit exact raw content including unescaped double quotes and single quotes
          cat <<'EOF'
Message with "double quotes" inside
Another line with it's fine
EOF
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          cat <<'EOF'
Merge branch 'feat-"quoted"-branch' into main
Merge branch 'feat-plain' into main
EOF
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]
  [ "$(grep '^changelog_string=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "Message with \"double quotes\" inside, Another line with it's fine" ]
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feat-\"quoted\"-branch, feat-plain" ]
}
