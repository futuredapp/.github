# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains reusable GitHub Actions workflows and composite actions for iOS, Android, and Kotlin Multiplatform (KMP) projects. These workflows are designed to be referenced from other projects using the pattern:

```yaml
jobs:
  job_name:
    uses: futuredapp/.github/.github/workflows/{platform}-{runner}-{action}.yml@{version}
```

## Project Structure

```
.github/
├── actions/           # Composite actions (reusable action components)
│   ├── android-*      # Android-specific actions
│   ├── ios-*          # iOS-specific actions
│   ├── kmp-*          # Kotlin Multiplatform actions
│   └── universal-*    # Platform-agnostic actions
└── workflows/         # Reusable workflows
    ├── android-*      # Android workflows
    ├── ios-*          # iOS workflows
    ├── kmp-*          # KMP workflows
    └── universal-*    # Platform-agnostic workflows
```

## Key Architecture Patterns

### Workflow Composition
- **Reusable Workflows** (in `.github/workflows/`): Entry points called by consumer projects, handle secrets and high-level orchestration
- **Composite Actions** (in `.github/actions/`): Modular building blocks that workflows use, contain the actual implementation logic
- Actions are referenced using `futuredapp/.github/.github/actions/{action-name}@main` pattern

### Change Detection System
The `universal-detect-changes-and-generate-changelog` action is critical infrastructure:
- Uses GitHub Actions cache to track the last successfully built commit
- Determines if builds should be skipped based on changes since last build
- Generates changelogs from merged branch names
- Composed of three modular bash scripts:
  - `cache-keys.sh`: Handles cache key generation with custom prefixes
  - `determine-range.sh`: Determines commit range and skip build logic
  - `generate-changelog.sh`: Formats changelog and extracts merged branches
- Used by nightly build workflows to avoid rebuilding unchanged code

### Platform Detection for KMP
The `kmp-detect-changes` action detects whether iOS or Android files changed:
- Uses `dorny/paths-filter` to identify which platform(s) need building
- iOS files: All files except those in `androidApp/`
- Android files: All files except those in `iosApp/`

### Runner Types
- **Cloud runners**: Use `ubuntu-latest` for cost efficiency (Android, universal tasks)
- **Self-hosted runners**: Required for iOS builds (macOS with Xcode)
- Runner labels are configurable via `runner_label` input (default: `self-hosted`)

## Common Commands

### Testing Bash Scripts
Several actions include BATS (Bash Automated Testing System) tests:

```bash
# Install BATS (if not already installed)
brew install bats-core  # macOS
apt-get install bats    # Ubuntu/Debian

# Run changelog action tests
cd .github/actions/universal-detect-changes-and-generate-changelog/test
./run_tests.sh

# Run specific changelog test file
bats test_cache-keys.bats
bats test_determine-range.bats
bats test_generate-changelog.bats

# Run release action version tag parsing tests
cd .github/actions/ios-fastlane-release/test
bats test_parse-version-tag.bats
```

### Linting Workflows
```bash
# Download and run actionlint
bash <(curl https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)
./actionlint -color
```

### Android Actions
Actions use Gradle tasks passed as inputs:
- Lint: `./gradlew --continue {LINT_GRADLE_TASK}`
- Test: `./gradlew --continue {TEST_GRADLE_TASK}`
- Build: `./gradlew {BUNDLE_GRADLE_TASK}` (for releases)

### iOS Actions
iOS actions wrap Fastlane scripts:
- Test: Runs Fastlane test lane
- Beta: Runs Fastlane beta lane (uploads to TestFlight)
- Release: Runs Fastlane release lane (submits to App Store)
  - The `version_number` input is parsed by `parse-version-tag.sh`: accepts `x.y.z` or `x.y.z-*` (any suffix after `-` is ignored, only `x.y.z` is extracted)
  - `build_number` is only set via the explicit `build_number` input (or Fastlane auto-increment); it is never derived from the version tag

All iOS actions support:
- `custom_values`: Environment variables in format "KEY1: value1; KEY2: value2"
- `custom_build_path`: Override default build output location

## Workflow Types by Platform

### iOS (Self-hosted)
- `ios-selfhosted-test`: Lint and test PRs
- `ios-selfhosted-nightly-build`: Automated nightly builds with changelog generation
- `ios-selfhosted-on-demand-build`: Manual builds triggered on-demand
- `ios-selfhosted-release`: Release builds for App Store submission

### iOS KMP (Self-hosted)
- `ios-kmp-selfhosted-test`: Lint and test PRs (KMP variant)
- `ios-kmp-selfhosted-build`: Enterprise builds with KMP shared code
- `ios-kmp-selfhosted-release`: Release builds with KMP shared code

### Android (Cloud)
- `android-cloud-check`: Unit tests and lint checks on PRs
- `android-cloud-nightly-build`: Automated nightly builds with Firebase distribution
- `android-cloud-release-firebaseAppDistribution`: QA snapshot releases to Firebase
- `android-cloud-release-googlePlay`: Production releases to Google Play
- `android-cloud-generate-baseline-profiles`: Generate and PR baseline profiles

### KMP (Cloud)
- `kmp-cloud-detect-changes`: Detect iOS/Android changes for conditional execution
- `kmp-combined-nightly-build`: Nightly builds for both iOS and Android

### Universal
- `workflows-lint`: Lint all workflow files using actionlint
- `universal-cloud-backup`: Backup current ref to remote repository (cloud runner)
- `universal-selfhosted-backup`: Backup current ref to remote repository (self-hosted)

## Important Conventions

### Secrets Management
- iOS workflows require App Store Connect API keys and Match password
- Android workflows require keystore passwords and Google Play service account JSON
- iOS actions support injecting secrets into `.xcconfig` files via `ios-export-secrets` action
- Android actions write secrets to `secrets.properties` file for Gradle pickup

### Build Artifacts
- iOS workflows upload `.ipa` and `.app.dSYM.zip` files to GitHub artifacts
- Android workflows upload `.aab` bundles directly to Google Play
- Artifacts are stored in `build_output/` directory

### Custom Values Format
Many workflows accept `custom_values` input for environment variables:
```
"KEY1: value1; KEY2: value2; KEY3: value3"
```

### Changelog Generation
- Changelogs are generated from merged branch names
- Falls back to 24-hour lookback window if no previous build is found
- Supports custom cache key prefixes for multi-variant builds
- Format: Lists merged branches since last successful build

### Concurrency Control
Test workflows use concurrency groups to cancel outdated runs:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref }}
  cancel-in-progress: true
```

## Maintainers

- Jakub Marek (<jakub.marek@futured.app>) - GitHub: @jmarek41
- Matej Semančík (<matej.semancik@futured.app>) - GitHub: @matejsemancik
