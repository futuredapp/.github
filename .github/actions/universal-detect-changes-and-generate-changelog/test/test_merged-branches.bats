#!/usr/bin/env bats

# Tests specifically for FORMATTED_BRANCH_NAMES output
# These tests focus on the branch name detection and extraction logic,
# separate from the changelog message formatting tests.

load 'test_helper'

# =============================================================================
# NESTED MERGE DETECTION:
# The generate-changelog.sh script now uses `git log --merges` (without --first-parent)
# combined with negative filtering to detect ALL merged branches including nested ones.
#
# The filtering logic: grep -v "Merge branch '(main|develop|master)' into"
# - Removes reverse merges (main→feature) used for conflict resolution
# - Keeps all forward merges (feature→feature and feature→main)
#
# This means nested merges (B→A→develop) now correctly detect both A and B!
# The tests below verify this behavior across various scenarios.
# =============================================================================

@test "merged-branches: detects nested merge when B is squash-merged to develop via A" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"
  export TARGET_BRANCH="(main|develop|master)"

  # Simulate git history where feature-A squashes commits from feature-B
  # Then feature-A merges to develop
  # In this case, when A is merged to develop, the changelog includes B's work
  # but B never directly merged to develop
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Feature A changelog"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          # Only the merge to develop is visible since B was squashed into A
          echo "Merge branch 'feature-A' into develop"
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # With positive filtering, only feature-A is detected
  # This is correct: B's commits are part of A, but B never merged to a main branch
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-A" ]

  # LIMITATION: If feature-B was a separate branch that merged into feature-A
  # with its own merge commit, and then feature-A merged to develop, we would
  # want to see both A and B IF both merge commits are present in the history.
  # This test shows the case where B was squashed (no separate merge commit).
}

@test "merged-branches: detects true nested merge B→A→develop with separate merge commits (FIXED)" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"
  export TARGET_BRANCH="(main|develop|master)"

  # Simulate git history where BOTH merges are present:
  # 1. feature-B has a merge commit into feature-A
  # 2. feature-A has a merge commit into develop
  # Without --first-parent, git log sees BOTH merge commits
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Feature A and B work"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          # Git log --merges (without --first-parent) returns BOTH merges
          echo "Merge branch 'feature-B' into feature-A"
          echo "Merge branch 'feature-A' into develop"
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # With NEGATIVE filtering: grep -v "Merge branch '(main|develop|master)' into"
  # - "Merge branch 'feature-B' into feature-A" is INCLUDED (B is not main/develop/master)
  # - "Merge branch 'feature-A' into develop" is INCLUDED (A is not main/develop/master)
  # Result: Both feature-A and feature-B are detected
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-A, feature-B" ]

  # This is the FIXED behavior - both nested branches are now detected!
}

@test "merged-branches: filters out conflict resolution merges (develop→A, then A→develop)" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"
  export TARGET_BRANCH="(main|develop|master)"

  # Simulate git history:
  # 1. develop merges into feature-A (conflict resolution - should be filtered out)
  # 2. feature-A merges into develop (actual feature merge - should be detected)
  #
  # Without --first-parent, git log sees BOTH merges, but negative filtering removes reverse merge
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Feature A implementation"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          # Both merges are now visible
          echo "Merge branch 'develop' into feature-A"
          echo "Merge branch 'feature-A' into develop"
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # With NEGATIVE filtering: grep -v "Merge branch '(main|develop|master)' into"
  # - "Merge branch 'develop' into feature-A" is FILTERED OUT (develop matches the pattern)
  # - "Merge branch 'feature-A' into develop" is INCLUDED (feature-A doesn't match)
  # Result: Only feature-A is detected
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-A" ]

  # This is CORRECT behavior - conflict resolution merges (main→feature) are filtered out
}

@test "merged-branches: multiple nested branches C→B→A→develop (FIXED)" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"
  export TARGET_BRANCH="(main|develop|master)"

  # Simulate git history:
  # 1. Branch C merges into branch B
  # 2. Branch B merges into branch A
  # 3. Branch A merges into develop
  #
  # Without --first-parent, all merge commits are visible
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Feature A with nested changes"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          # All merge commits are now visible
          echo "Merge branch 'feature-C' into feature-B"
          echo "Merge branch 'feature-B' into feature-A"
          echo "Merge branch 'feature-A' into develop"
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # FIXED BEHAVIOR: Detects all nested branches A, B, and C
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-A, feature-B, feature-C" ]

  # This demonstrates that deep nesting is now properly detected!
}

@test "merged-branches: parallel merges A and B separately to develop (WORKING CASE)" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"

  # Simulate git history:
  # 1. Branch A merges into develop
  # 2. Branch B merges into develop
  #
  # Both are on the first-parent path, so both should be detected
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Feature A implementation"
          echo "Feature B implementation"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature-A' into develop"
          echo "Merge branch 'feature-B' into develop"
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # CURRENT BEHAVIOR: Correctly detects both A and B
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-A, feature-B" ]

  # This is the EXPECTED working case - parallel merges work correctly
}

@test "merged-branches: mixed scenario with nested and parallel merges (FIXED)" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"
  export TARGET_BRANCH="(main|develop|master)"

  # Simulate git history:
  # 1. Branch B merges into branch A (nested)
  # 2. Branch A merges into develop
  # 3. Branch C merges into develop (parallel)
  #
  # All should be detected now
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Feature A with nested B"
          echo "Feature C standalone"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature-B' into feature-A"
          echo "Merge branch 'feature-A' into develop"
          echo "Merge branch 'feature-C' into develop"
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # FIXED BEHAVIOR: Detects A, B, and C
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-A, feature-B, feature-C" ]

  # This shows that both parallel and nested merges are now detected!
}

@test "merged-branches: handles pull request merge format" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"
  export TARGET_BRANCH="(main|develop|master)"

  # Test that pull request merge commits are properly parsed
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "PR body content"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge pull request #123 from org/feature-branch"
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # Should extract the branch name from the pull request format
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "org/feature-branch" ]
}

@test "merged-branches: handles branch names with special characters" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"
  export TARGET_BRANCH="(main|develop|master)"

  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Feature work"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature/PROJ-123/add-new-feature' into develop"
          echo "Merge branch 'bugfix/HOTFIX-456_critical-fix' into develop"
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # Should handle slashes, hyphens, underscores correctly
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "bugfix/HOTFIX-456_critical-fix, feature/PROJ-123/add-new-feature" ]
}

@test "merged-branches: deduplicates branch names across merge commits" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"
  export TARGET_BRANCH="(main|develop|master)"

  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Multiple merges"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature-A' into develop"
          echo "Merge branch 'feature-B' into develop"
          echo "Merge branch 'feature-A' into develop"  # Duplicate
          echo "Merge branch 'feature-C' into develop"
          echo "Merge branch 'feature-B' into develop"  # Duplicate
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # Should deduplicate and sort
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-A, feature-B, feature-C" ]
}

@test "merged-branches: handles empty output when no merges found" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"
  export TARGET_BRANCH="(main|develop|master)"

  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Some changelog"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo ""  # No merge commits
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # Should handle empty branch names gracefully
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "" ]
}

@test "merged-branches: handles branch names with quotes" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"
  export TARGET_BRANCH="(main|develop|master)"

  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Feature work"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'feature-\"quoted\"-name' into develop"
          echo "Merge branch 'another-'single'-quoted' into develop"
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # Should preserve quotes in branch names
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "another-'single'-quoted, feature-\"quoted\"-name" ]
}

@test "merged-branches: supports custom target branch pattern" {
  export FROM_COMMIT="base-commit"
  export TO_COMMIT="HEAD"
  export DEBUG="false"
  export TARGET_BRANCH="(release|production)"

  # Test custom target branch filtering
  git() {
    case "$1" in
      "log")
        if [[ "$*" == *"--pretty=format:%b"* ]]; then
          echo "Release work"
        elif [[ "$*" == *"--pretty=format:%s"* ]]; then
          echo "Merge branch 'main' into feature-A"  # Should be filtered out
          echo "Merge branch 'feature-A' into release"  # Should be included
          echo "Merge branch 'feature-B' into production"  # Should be included
          echo "Merge branch 'feature-C' into develop"  # Should be included (not filtered by custom pattern)
        fi
        return 0
        ;;
    esac
  }
  export -f git

  run "$BATS_TEST_DIRNAME/../generate-changelog.sh"

  [ "$status" -eq 0 ]

  # The negative filter grep -v "Merge branch '(release|production)' into"
  # filters out: "Merge branch 'main' into feature-A" (NO - main doesn't match pattern)
  # Actually, it filters nothing because none of the sources match (release|production)
  # Wait, the filter is looking for the SOURCE branch, not the target!
  # So "Merge branch 'main' into feature-A" - source is 'main', doesn't match filter, INCLUDED
  # "Merge branch 'feature-A' into release" - source is 'feature-A', doesn't match, INCLUDED
  # etc.
  # The filter only removes merges where the SOURCE is release/production/main
  # With pattern "(release|production)", only "Merge branch 'release...' or 'production...'" are filtered
  # So all four should be included since none have release/production as source

  # Wait, let me reconsider the logic...
  # grep -v -E "Merge branch '(${TARGET_BRANCH})' into"
  # This matches: "Merge branch 'release' into ..." or "Merge branch 'production' into ..."
  # So it EXCLUDES merges where release or production is the SOURCE
  # In our test, no merge has release/production as source, so all are included
  [ "$(grep '^merged_branches=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "feature-A, feature-B, feature-C, main" ]

  # This demonstrates that TARGET_BRANCH is configurable for different workflows
}
