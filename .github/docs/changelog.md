# Changelog

All notable changes to Futured CI/CD Workflows.

## 2.2.1

_2026-03-23_

### Input changes

#### `ios-fastlane-beta`

| Input | Change | Details |
|---|---|---|
| `build_number` | :material-plus: Added | type: `string` |
| `version_number` | :material-plus: Added | type: `string` |

#### `ios-fastlane-release`

| Input | Change | Details |
|---|---|---|
| `build_number` | :material-plus: Added | type: `string` |
| `version_number` | :material-pencil: Modified | description updated |

#### `ios-selfhosted-on-demand-build`

| Input | Change | Details |
|---|---|---|
| `build_number` | :material-plus: Added | type: `string` |
| `version_number` | :material-plus: Added | type: `string` |

### Internal changes

- `android-cloud-check`
- `android-cloud-generate-baseline-profiles`
- `android-cloud-nightly-build`
- `android-cloud-release-firebaseAppDistribution`
- `android-cloud-release-googlePlay`
- `ios-kmp-selfhosted-build`
- `ios-kmp-selfhosted-release`
- `ios-kmp-selfhosted-test`
- `ios-selfhosted-nightly-build`
- `ios-selfhosted-release`
- `ios-selfhosted-test`
- `kmp-combined-nightly-build`
- `universal-cloud-backup`
- `universal-selfhosted-backup`
- `workflows-lint`
- `android-build-firebase`
- `android-build-googlePlay`
- `android-check`
- `android-generate-baseline-profiles`
- `android-setup-environment`
- `ios-fastlane-test`
- `ios-kmp-build`
- `kmp-detect-changes`
- `universal-detect-changes-and-generate-changelog`

**Contributors:** Jakub Marek, Šimon Šesták

---

## 2.2.0

_2026-02-20_

### Input changes

#### `universal-detect-changes-and-generate-changelog`

| Input | Change | Details |
|---|---|---|
| `exclude_source_branches` | :material-plus: Added | type: `string`, default: `(main|develop|master)` |

**Contributors:** Matej Semančík, Šimon Šesták

---

## 2.1.0

_2025-11-14_

### Breaking changes

#### Workflows

- **`ios-selfhosted-nightly-build`**
    - Removed input `secret_properties`
- **`ios-selfhosted-on-demand-build`**
    - Removed input `secret_properties`
- **`ios-selfhosted-release`**
    - Removed input `secret_properties`

### New workflows & actions

- Added action `jira-transition-tickets`

### Removed workflows & actions

- Removed workflow `test-universal-detect-changes`

### Input changes

#### `android-cloud-nightly-build`

| Input | Change | Details |
|---|---|---|
| `JIRA_TRANSITION` | :material-plus: Added | type: `string`, default: `Testing` |

| Secret | Change | Details |
|---|---|---|
| `JIRA_CONTEXT` | :material-plus: Added |  |

#### `ios-selfhosted-nightly-build`

| Input | Change | Details |
|---|---|---|
| `checkout_depth` | :material-plus: Added | type: `number`, default: `100` |
| `custom_values` | :material-pencil: Modified | default: _none_ -> `24 hours` |
| `jira_transition` | :material-plus: Added | type: `string`, default: `Testing` |
| `secret_properties` | :material-minus: Removed |  |

| Secret | Change | Details |
|---|---|---|
| `JIRA_CONTEXT` | :material-plus: Added |  |

#### `ios-selfhosted-on-demand-build`

| Input | Change | Details |
|---|---|---|
| `checkout_depth` | :material-plus: Added | type: `number`, default: `100` |
| `secret_properties` | :material-minus: Removed |  |

#### `ios-selfhosted-release`

| Input | Change | Details |
|---|---|---|
| `secret_properties` | :material-minus: Removed |  |

#### `kmp-combined-nightly-build`

| Input | Change | Details |
|---|---|---|
| `JIRA_TRANSITION` | :material-plus: Added | type: `string`, default: `Testing` |

| Secret | Change | Details |
|---|---|---|
| `JIRA_CONTEXT` | :material-plus: Added |  |

#### `universal-detect-changes-and-generate-changelog`

| Input | Change | Details |
|---|---|---|
| `use_git_lfs` | :material-plus: Added | type: `boolean`, default: `False` |

### Internal changes

- `ios-selfhosted-build`
- `workflows-lint`

**Contributors:** Jakub Marek, Matej Semančík, Šimon Šesták

---

## 2.0.1

_2025-11-12_

### Breaking changes

#### Workflows

- **`ios-selfhosted-build`**
    - Removed input `changelog_checkout_depth`
    - Removed input `changelog_debug`
    - Removed input `force_build`

### New workflows & actions

- Added workflow `ios-selfhosted-nightly-build`
- Added workflow `ios-selfhosted-on-demand-build`
- Added workflow `test-universal-detect-changes`
- Added action `ios-fastlane-beta`
- Added action `ios-fastlane-release`
- Added action `ios-fastlane-test`

### Input changes

#### `android-check`

| Input | Change | Details |
|---|---|---|
| `github_token_danger` | :material-plus: Added | type: `string` |

#### `android-cloud-check`

| Secret | Change | Details |
|---|---|---|
| `GITHUB_TOKEN_DANGER` | :material-plus: Added |  |

#### `ios-kmp-build`

| Input | Change | Details |
|---|---|---|
| `ios_custom_build_path` | :material-plus: Added | type: `string` |

#### `ios-kmp-selfhosted-build`

| Input | Change | Details |
|---|---|---|
| `custom_build_path` | :material-plus: Added | type: `string` |

#### `ios-kmp-selfhosted-release`

| Input | Change | Details |
|---|---|---|
| `custom_build_path` | :material-plus: Added | type: `string` |

#### `ios-kmp-selfhosted-test`

| Input | Change | Details |
|---|---|---|
| `custom_build_path` | :material-plus: Added | type: `string` |

| Secret | Change | Details |
|---|---|---|
| `GITHUB_TOKEN_DANGER` | :material-plus: Added |  |

#### `ios-selfhosted-build`

| Input | Change | Details |
|---|---|---|
| `changelog_checkout_depth` | :material-minus: Removed |  |
| `changelog_debug` | :material-minus: Removed |  |
| `force_build` | :material-minus: Removed |  |
| `required_keys` | :material-pencil: Modified | default: `` -> _none_ |
| `secret_properties` | :material-plus: Added | type: `string` |
| `timeout_minutes` | :material-plus: Added | type: `number`, default: `30` |
| `xcconfig_path` | :material-pencil: Modified | default: `` -> _none_ |

#### `ios-selfhosted-release`

| Input | Change | Details |
|---|---|---|
| `required_keys` | :material-pencil: Modified | default: `` -> _none_ |
| `secret_properties` | :material-plus: Added | type: `string` |
| `timeout_minutes` | :material-plus: Added | type: `number`, default: `30` |
| `xcconfig_path` | :material-pencil: Modified | default: `` -> _none_ |

#### `ios-selfhosted-test`

| Input | Change | Details |
|---|---|---|
| `timeout_minutes` | :material-plus: Added | type: `number`, default: `30` |

| Secret | Change | Details |
|---|---|---|
| `GITHUB_TOKEN_DANGER` | :material-plus: Added |  |

#### `kmp-combined-nightly-build`

| Input | Change | Details |
|---|---|---|
| `IOS_CUSTOM_BUILD_PATH` | :material-plus: Added | type: `string` |

#### `universal-detect-changes-and-generate-changelog`

| Input | Change | Details |
|---|---|---|
| `cache_key_prefix` | :material-plus: Added | type: `string` |

### Internal changes

- `android-build-firebase`

**Contributors:** Matej Semančík, Ondřej Kalman, Patrik Potoček, Šimon Šesták

---

## 2.0.0

_2025-10-07_

### Breaking changes

#### Workflows

- **`android-cloud-release-firebaseAppDistribution`**
    - Removed input `BUNDLE_GRADLE_TASK`
    - Removed input `SIGNING_KEYSTORE_PATH`
    - Removed secret `SIGNING_KEYSTORE_PASSWORD`
    - Removed secret `SIGNING_KEY_ALIAS`
    - Removed secret `SIGNING_KEY_PASSWORD`
- **`android-cloud-release-googlePlay`**
    - Removed input `SIGNING_KEYSTORE_PATH`

### New workflows & actions

- Added workflow `android-cloud-generate-baseline-profiles`
- Added workflow `android-cloud-nightly-build`
- Added workflow `kmp-combined-nightly-build`
- Added action `android-build-firebase`
- Added action `android-build-googlePlay`
- Added action `android-check`
- Added action `android-generate-baseline-profiles`
- Added action `android-setup-environment`
- Added action `ios-export-secrets`
- Added action `ios-kmp-build`
- Added action `kmp-detect-changes`

### Removed workflows & actions

- Removed workflow `android-generate-baseline-profiles`
- Removed workflow `ios-cloud-build`
- Removed workflow `ios-cloud-release`
- Removed workflow `ios-cloud-test`
- Removed action `export_secrets_ios`

### Input changes

#### `android-cloud-release-firebaseAppDistribution`

| Input | Change | Details |
|---|---|---|
| `BUNDLE_GRADLE_TASK` | :material-minus: Removed |  |
| `PACKAGE_GRADLE_TASK` | :material-plus: Added | type: `string`, required |
| `SIGNING_KEYSTORE_PATH` | :material-minus: Removed |  |

| Secret | Change | Details |
|---|---|---|
| `SIGNING_KEYSTORE_PASSWORD` | :material-minus: Removed |  |
| `SIGNING_KEY_ALIAS` | :material-minus: Removed |  |
| `SIGNING_KEY_PASSWORD` | :material-minus: Removed |  |

#### `android-cloud-release-googlePlay`

| Input | Change | Details |
|---|---|---|
| `SIGNING_KEYSTORE_PATH` | :material-minus: Removed |  |

#### `ios-kmp-selfhosted-build`

| Input | Change | Details |
|---|---|---|
| `changelog` | :material-plus: Added | type: `string`, default: `${{ github.event.pull_request.title }}` |

#### `ios-selfhosted-build`

| Input | Change | Details |
|---|---|---|
| `force_build` | :material-plus: Added | type: `boolean`, default: `False` |

#### `universal-detect-changes-and-generate-changelog`

| Output | Change |
|---|---|
| `cache_key` | :material-plus: Added |

### Internal changes

- `android-cloud-check`
- `ios-kmp-selfhosted-release`
- `ios-selfhosted-release`
- `kmp-cloud-detect-changes`

**Contributors:** Jakub Marek, Matej Semančík, Šimon Šesták

---

## 1.4.0

_2025-08-27_

Same as 1.3.1 (re-tagged).

---

## 1.3.1

_2025-08-27_

### New workflows & actions

- Added workflow `android-generate-baseline-profiles`
- Added action `export_secrets_ios`
- Added action `universal-detect-changes-and-generate-changelog`

### Input changes

#### `ios-cloud-build`

| Input | Change | Details |
|---|---|---|
| `required_keys` | :material-plus: Added | type: `string`, default: `` |
| `xcconfig_path` | :material-plus: Added | type: `string`, default: `` |

| Secret | Change | Details |
|---|---|---|
| `SECRET_PROPERTIES` | :material-plus: Added |  |

#### `ios-cloud-release`

| Input | Change | Details |
|---|---|---|
| `required_keys` | :material-plus: Added | type: `string`, default: `` |
| `xcconfig_path` | :material-plus: Added | type: `string`, default: `` |

| Secret | Change | Details |
|---|---|---|
| `SECRET_PROPERTIES` | :material-plus: Added |  |

#### `ios-kmp-selfhosted-build`

| Input | Change | Details |
|---|---|---|
| `java_distribution` | :material-plus: Added | type: `string`, default: `zulu` |
| `java_version` | :material-plus: Added | type: `string`, default: `17` |
| `required_keys` | :material-plus: Added | type: `string`, default: `` |
| `xcconfig_path` | :material-plus: Added | type: `string`, default: `` |

| Secret | Change | Details |
|---|---|---|
| `SECRET_PROPERTIES` | :material-plus: Added |  |

#### `ios-kmp-selfhosted-release`

| Input | Change | Details |
|---|---|---|
| `java_distribution` | :material-plus: Added | type: `string`, default: `zulu` |
| `java_version` | :material-plus: Added | type: `string`, default: `17` |
| `required_keys` | :material-plus: Added | type: `string`, default: `` |
| `xcconfig_path` | :material-plus: Added | type: `string`, default: `` |

| Secret | Change | Details |
|---|---|---|
| `SECRET_PROPERTIES` | :material-plus: Added |  |

#### `ios-kmp-selfhosted-test`

| Input | Change | Details |
|---|---|---|
| `java_distribution` | :material-plus: Added | type: `string`, default: `zulu` |
| `java_version` | :material-plus: Added | type: `string`, default: `17` |

#### `ios-selfhosted-build`

| Input | Change | Details |
|---|---|---|
| `changelog_checkout_depth` | :material-plus: Added | type: `number`, default: `100` |
| `changelog_debug` | :material-plus: Added | type: `boolean`, default: `False` |
| `changelog_fallback_lookback` | :material-plus: Added | type: `string`, default: `24 hours` |
| `required_keys` | :material-plus: Added | type: `string`, default: `` |
| `runner_label` | :material-plus: Added | type: `string`, default: `self-hosted` |
| `xcconfig_path` | :material-plus: Added | type: `string`, default: `` |

| Secret | Change | Details |
|---|---|---|
| `SECRET_PROPERTIES` | :material-plus: Added |  |

#### `ios-selfhosted-release`

| Input | Change | Details |
|---|---|---|
| `required_keys` | :material-plus: Added | type: `string`, default: `` |
| `runner_label` | :material-plus: Added | type: `string`, default: `self-hosted` |
| `xcconfig_path` | :material-plus: Added | type: `string`, default: `` |

| Secret | Change | Details |
|---|---|---|
| `SECRET_PROPERTIES` | :material-plus: Added |  |

#### `ios-selfhosted-test`

| Input | Change | Details |
|---|---|---|
| `runner_label` | :material-plus: Added | type: `string`, default: `self-hosted` |

### Internal changes

- `ios-cloud-test`

**Contributors:** Honza Mikulík, Rudolf Hladík, Šimon Šesták

---

## 1.3.0

_2025-06-05_

### Input changes

#### `android-cloud-check`

| Input | Change | Details |
|---|---|---|
| `USE_GIT_LFS` | :material-plus: Added | type: `boolean`, default: `False` |

| Secret | Change | Details |
|---|---|---|
| `GRADLE_CACHE_ENCRYPTION_KEY` | :material-plus: Added |  |

#### `android-cloud-release-firebaseAppDistribution`

| Input | Change | Details |
|---|---|---|
| `USE_GIT_LFS` | :material-plus: Added | type: `boolean`, default: `False` |

| Secret | Change | Details |
|---|---|---|
| `GRADLE_CACHE_ENCRYPTION_KEY` | :material-plus: Added |  |

#### `android-cloud-release-googlePlay`

| Input | Change | Details |
|---|---|---|
| `USE_GIT_LFS` | :material-plus: Added | type: `boolean`, default: `False` |

#### `ios-kmp-selfhosted-build`

| Secret | Change | Details |
|---|---|---|
| `GRADLE_CACHE_ENCRYPTION_KEY` | :material-plus: Added |  |

#### `ios-kmp-selfhosted-test`

| Secret | Change | Details |
|---|---|---|
| `GRADLE_CACHE_ENCRYPTION_KEY` | :material-plus: Added |  |

#### `kmp-cloud-detect-changes`

| Input | Change | Details |
|---|---|---|
| `USE_GIT_LFS` | :material-plus: Added | type: `boolean`, default: `False` |

### Internal changes

- `ios-kmp-selfhosted-release`

**Contributors:** Honza Mikulík, Matej Semančík

---

## 1.2.0

_2025-03-13_

### Breaking changes

#### Workflows

- **`ios-kmp-selfhosted-release`**
    - Removed secret `APP_STORE_CONNECT_API_KEY_ISSUER_ID_CUSTOMER`
    - Removed secret `APP_STORE_CONNECT_API_KEY_KEY_CUSTOMER`
    - Removed secret `APP_STORE_CONNECT_API_KEY_KEY_ID_CUSTOMER`

### Input changes

#### `android-cloud-check`

| Input | Change | Details |
|---|---|---|
| `GRADLE_OPTS` | :material-plus: Added | type: `string`, default: `` |

#### `android-cloud-release-firebaseAppDistribution`

| Input | Change | Details |
|---|---|---|
| `GRADLE_OPTS` | :material-plus: Added | type: `string`, default: `` |
| `SECRET_PROPERTIES_FILE` | :material-pencil: Modified | description updated |
| `VERSION_NAME` | :material-pencil: Modified | default: `1.X.X-snapshot` -> _none_ |

#### `android-cloud-release-googlePlay`

| Input | Change | Details |
|---|---|---|
| `GRADLE_OPTS` | :material-plus: Added | type: `string`, default: `` |

#### `ios-kmp-selfhosted-build`

| Input | Change | Details |
|---|---|---|
| `kmp_swift_package_flavor` | :material-plus: Added | type: `string`, default: `prod` |
| `kmp_swift_package_integration` | :material-plus: Added | type: `boolean`, default: `False` |
| `kmp_swift_package_path` | :material-plus: Added | type: `string`, default: `iosApp/shared/KMP` |

#### `ios-kmp-selfhosted-release`

| Input | Change | Details |
|---|---|---|
| `kmp_swift_package_flavor` | :material-plus: Added | type: `string`, default: `prod` |
| `kmp_swift_package_integration` | :material-plus: Added | type: `boolean`, default: `False` |
| `kmp_swift_package_path` | :material-plus: Added | type: `string`, default: `iosApp/shared/KMP` |

| Secret | Change | Details |
|---|---|---|
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID_CUSTOMER` | :material-minus: Removed |  |
| `APP_STORE_CONNECT_API_KEY_KEY_CUSTOMER` | :material-minus: Removed |  |
| `APP_STORE_CONNECT_API_KEY_KEY_ID_CUSTOMER` | :material-minus: Removed |  |

#### `ios-kmp-selfhosted-test`

| Input | Change | Details |
|---|---|---|
| `kmp_swift_package_flavor` | :material-plus: Added | type: `string`, default: `dev` |
| `kmp_swift_package_integration` | :material-plus: Added | type: `boolean`, default: `False` |
| `kmp_swift_package_path` | :material-plus: Added | type: `string`, default: `iosApp/shared/KMP` |

#### `universal-cloud-backup`

| Input | Change | Details |
|---|---|---|
| `push_tags` | :material-plus: Added | type: `boolean`, default: `False` |

#### `universal-selfhosted-backup`

| Input | Change | Details |
|---|---|---|
| `push_tags` | :material-plus: Added | type: `boolean`, default: `False` |

**Contributors:** Jakub Marek, Jan Maděra, Matej Semančík

---

## 1.1.1

_2025-02-07_

### Input changes

#### `android-cloud-release-firebaseAppDistribution`

| Input | Change | Details |
|---|---|---|
| `RELEASE_NOTES` | :material-plus: Added | type: `string`, default: `${{ github.event.head_commit.message }}` |

**Contributors:** Matej Semančík

---

## 1.1.0

_2025-01-30_

### New workflows & actions

- Added workflow `android-cloud-check`
- Added workflow `android-cloud-release-firebaseAppDistribution`
- Added workflow `android-cloud-release-googlePlay`
- Added workflow `kmp-cloud-detect-changes`

### Input changes

#### `ios-kmp-selfhosted-build`

| Input | Change | Details |
|---|---|---|
| `timeout_minutes` | :material-plus: Added | type: `number`, default: `30` |

#### `ios-kmp-selfhosted-test`

| Input | Change | Details |
|---|---|---|
| `timeout_minutes` | :material-plus: Added | type: `number`, default: `30` |

**Contributors:** Matej Semančík

---

## 1.0.0

_2024-10-24_

Initial release. Versioned shared workflows for iOS and KMP projects.

### Workflows

- `ios-cloud-build`
- `ios-cloud-release`
- `ios-cloud-test`
- `ios-kmp-selfhosted-build`
- `ios-kmp-selfhosted-release`
- `ios-kmp-selfhosted-test`
- `ios-selfhosted-build`
- `ios-selfhosted-release`
- `ios-selfhosted-test`
- `universal-cloud-backup`
- `universal-selfhosted-backup`
- `workflows-lint`

**Contributors:** Filip Procházka, Jakub Marek, Matěj Kašpar Jirásek, Michal Martinů, Ondřej Kalman, Šimon Šesták
