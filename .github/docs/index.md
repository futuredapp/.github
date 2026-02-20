# Futured CI/CD Workflows

Reusable GitHub Actions workflows and composite actions for **iOS**, **Android**, and **Kotlin Multiplatform** projects at Futured.

---

## What's Inside

<div class="grid cards" markdown>

-   :material-apple:{ .lg .middle } **iOS Workflows**

    ---

    Self-hosted runner workflows for testing, building, and releasing iOS apps via Fastlane.

    [:octicons-arrow-right-24: iOS Workflows](workflows/ios/index.md)

-   :material-android:{ .lg .middle } **Android Workflows**

    ---

    Cloud-based workflows for PR checks, nightly builds, and releases to Firebase & Google Play.

    [:octicons-arrow-right-24: Android Workflows](workflows/android/index.md)

-   :material-language-kotlin:{ .lg .middle } **KMP Workflows**

    ---

    Workflows for Kotlin Multiplatform projects — change detection and combined builds.

    [:octicons-arrow-right-24: KMP Workflows](workflows/kmp/index.md)

-   :material-cog:{ .lg .middle } **Composite Actions**

    ---

    Reusable building blocks used by the workflows — environment setup, Fastlane steps, and utilities.

    [:octicons-arrow-right-24: Actions](actions/index.md)

</div>

---

## Quick Links

| Platform | Test | Build | Release |
|----------|------|-------|---------|
| **iOS** | [selfhosted-test](workflows/ios/selfhosted-test.md) | [selfhosted-nightly-build](workflows/ios/selfhosted-nightly-build.md) | [selfhosted-release](workflows/ios/selfhosted-release.md) |
| **iOS + KMP** | [selfhosted-test](workflows/ios-kmp/selfhosted-test.md) | [selfhosted-build](workflows/ios-kmp/selfhosted-build.md) | [selfhosted-release](workflows/ios-kmp/selfhosted-release.md) |
| **Android** | [cloud-check](workflows/android/cloud-check.md) | [cloud-nightly-build](workflows/android/cloud-nightly-build.md) | [Firebase](workflows/android/cloud-release-firebase.md) / [Google Play](workflows/android/cloud-release-googleplay.md) |
| **KMP** | — | [combined-nightly-build](workflows/kmp/combined-nightly-build.md) | — |

---

## Repository

[:fontawesome-brands-github: futuredapp/.github](https://github.com/futuredapp/.github){ .md-button }
