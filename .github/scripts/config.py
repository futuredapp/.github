"""Registry mapping every workflow and action to its documentation metadata."""

from __future__ import annotations

# Categories: ios, ios-kmp, android, kmp, universal, utility

WORKFLOWS: dict[str, dict] = {
    "ios-selfhosted-test": {
        "source": "workflows/ios-selfhosted-test.yml",
        "category": "ios",
        "title": "iOS Test",
        "output": "docs/workflows/ios/selfhosted-test.md",
        "runner": "Self-hosted",
    },
    "ios-selfhosted-nightly-build": {
        "source": "workflows/ios-selfhosted-nightly-build.yml",
        "category": "ios",
        "title": "iOS Nightly Build",
        "output": "docs/workflows/ios/selfhosted-nightly-build.md",
        "runner": "Self-hosted",
    },
    "ios-selfhosted-on-demand-build": {
        "source": "workflows/ios-selfhosted-on-demand-build.yml",
        "category": "ios",
        "title": "iOS On-Demand Build",
        "output": "docs/workflows/ios/selfhosted-on-demand-build.md",
        "runner": "Self-hosted",
    },
    "ios-selfhosted-release": {
        "source": "workflows/ios-selfhosted-release.yml",
        "category": "ios",
        "title": "iOS Release",
        "output": "docs/workflows/ios/selfhosted-release.md",
        "runner": "Self-hosted",
    },
    "ios-selfhosted-build": {
        "source": "workflows/ios-selfhosted-build.yml",
        "category": "ios",
        "title": "iOS Build (Deprecated)",
        "output": "docs/workflows/ios/selfhosted-build.md",
        "runner": "Self-hosted",
        "deprecated": True,
        "deprecated_message": "Use `ios-selfhosted-nightly-build` instead.",
    },
    "ios-kmp-selfhosted-test": {
        "source": "workflows/ios-kmp-selfhosted-test.yml",
        "category": "ios-kmp",
        "title": "iOS KMP Test",
        "output": "docs/workflows/ios-kmp/selfhosted-test.md",
        "runner": "Self-hosted",
    },
    "ios-kmp-selfhosted-build": {
        "source": "workflows/ios-kmp-selfhosted-build.yml",
        "category": "ios-kmp",
        "title": "iOS KMP Build",
        "output": "docs/workflows/ios-kmp/selfhosted-build.md",
        "runner": "Self-hosted",
    },
    "ios-kmp-selfhosted-release": {
        "source": "workflows/ios-kmp-selfhosted-release.yml",
        "category": "ios-kmp",
        "title": "iOS KMP Release",
        "output": "docs/workflows/ios-kmp/selfhosted-release.md",
        "runner": "Self-hosted",
    },
    "android-cloud-check": {
        "source": "workflows/android-cloud-check.yml",
        "category": "android",
        "title": "Android PR Check",
        "output": "docs/workflows/android/cloud-check.md",
        "runner": "ubuntu-latest",
    },
    "android-cloud-nightly-build": {
        "source": "workflows/android-cloud-nightly-build.yml",
        "category": "android",
        "title": "Android Nightly Build",
        "output": "docs/workflows/android/cloud-nightly-build.md",
        "runner": "ubuntu-latest",
    },
    "android-cloud-release-firebase": {
        "source": "workflows/android-cloud-release-firebaseAppDistribution.yml",
        "category": "android",
        "title": "Android Release (Firebase)",
        "output": "docs/workflows/android/cloud-release-firebase.md",
        "runner": "ubuntu-latest",
    },
    "android-cloud-release-googleplay": {
        "source": "workflows/android-cloud-release-googlePlay.yml",
        "category": "android",
        "title": "Android Release (Google Play)",
        "output": "docs/workflows/android/cloud-release-googleplay.md",
        "runner": "ubuntu-latest",
    },
    "android-cloud-generate-baseline-profiles": {
        "source": "workflows/android-cloud-generate-baseline-profiles.yml",
        "category": "android",
        "title": "Android Generate Baseline Profiles",
        "output": "docs/workflows/android/cloud-generate-baseline-profiles.md",
        "runner": "ubuntu-latest",
    },
    "kmp-cloud-detect-changes": {
        "source": "workflows/kmp-cloud-detect-changes.yml",
        "category": "kmp",
        "title": "KMP Detect Changes",
        "output": "docs/workflows/kmp/cloud-detect-changes.md",
        "runner": "ubuntu-latest",
    },
    "kmp-combined-nightly-build": {
        "source": "workflows/kmp-combined-nightly-build.yml",
        "category": "kmp",
        "title": "KMP Combined Nightly Build",
        "output": "docs/workflows/kmp/combined-nightly-build.md",
        "runner": "Self-hosted + ubuntu-latest",
    },
    "universal-cloud-backup": {
        "source": "workflows/universal-cloud-backup.yml",
        "category": "universal",
        "title": "Cloud Backup",
        "output": "docs/workflows/universal/cloud-backup.md",
        "runner": "ubuntu-latest",
    },
    "universal-selfhosted-backup": {
        "source": "workflows/universal-selfhosted-backup.yml",
        "category": "universal",
        "title": "Self-hosted Backup",
        "output": "docs/workflows/universal/selfhosted-backup.md",
        "runner": "Self-hosted",
    },
    "workflows-lint": {
        "source": "workflows/workflows-lint.yml",
        "category": "universal",
        "title": "Workflows Lint",
        "output": "docs/workflows/universal/workflows-lint.md",
        "runner": "ubuntu-latest",
        "not_reusable": True,
    },
}

ACTIONS: dict[str, dict] = {
    "android-setup-environment": {
        "source": "actions/android-setup-environment/action.yml",
        "category": "android",
        "title": "Setup Environment",
        "output": "docs/actions/android/setup-environment.md",
    },
    "android-check": {
        "source": "actions/android-check/action.yml",
        "category": "android",
        "title": "Android Check",
        "output": "docs/actions/android/check.md",
    },
    "android-build-firebase": {
        "source": "actions/android-build-firebase/action.yml",
        "category": "android",
        "title": "Build Firebase",
        "output": "docs/actions/android/build-firebase.md",
    },
    "android-build-googleplay": {
        "source": "actions/android-build-googlePlay/action.yml",
        "category": "android",
        "title": "Build Google Play",
        "output": "docs/actions/android/build-googleplay.md",
    },
    "android-generate-baseline-profiles": {
        "source": "actions/android-generate-baseline-profiles/action.yml",
        "category": "android",
        "title": "Generate Baseline Profiles",
        "output": "docs/actions/android/generate-baseline-profiles.md",
    },
    "ios-export-secrets": {
        "source": "actions/ios-export-secrets/action.yml",
        "category": "ios",
        "title": "Export Secrets",
        "output": "docs/actions/ios/export-secrets.md",
    },
    "ios-fastlane-test": {
        "source": "actions/ios-fastlane-test/action.yml",
        "category": "ios",
        "title": "Fastlane Test",
        "output": "docs/actions/ios/fastlane-test.md",
    },
    "ios-fastlane-beta": {
        "source": "actions/ios-fastlane-beta/action.yml",
        "category": "ios",
        "title": "Fastlane Beta",
        "output": "docs/actions/ios/fastlane-beta.md",
    },
    "ios-fastlane-release": {
        "source": "actions/ios-fastlane-release/action.yml",
        "category": "ios",
        "title": "Fastlane Release",
        "output": "docs/actions/ios/fastlane-release.md",
    },
    "ios-kmp-build": {
        "source": "actions/ios-kmp-build/action.yml",
        "category": "ios",
        "title": "KMP Build",
        "output": "docs/actions/ios/kmp-build.md",
    },
    "kmp-detect-changes": {
        "source": "actions/kmp-detect-changes/action.yml",
        "category": "utility",
        "title": "KMP Detect Changes",
        "output": "docs/actions/utility/kmp-detect-changes.md",
    },
    "universal-detect-changes-and-generate-changelog": {
        "source": "actions/universal-detect-changes-and-generate-changelog/action.yml",
        "category": "utility",
        "title": "Detect Changes & Changelog",
        "output": "docs/actions/utility/detect-changes-changelog.md",
        "readme": "actions/universal-detect-changes-and-generate-changelog/README.md",
    },
    "jira-transition-tickets": {
        "source": "actions/jira-transition-tickets/action.yml",
        "category": "utility",
        "title": "JIRA Transition Tickets",
        "output": "docs/actions/utility/jira-transition-tickets.md",
        "readme": "actions/jira-transition-tickets/README.md",
    },
}

CATEGORY_LABELS: dict[str, str] = {
    "ios": "iOS",
    "ios-kmp": "iOS + KMP",
    "android": "Android",
    "kmp": "KMP",
    "universal": "Universal",
    "utility": "Utility",
}
