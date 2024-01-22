# Futured GitHub configuration

## Reusable workflows

This repo contains reusable workflows. These workflows are automatically
set up when creating projects using
[iOS project template](https://github.com/futuredapp/iOS-project-template).

If you want to import them manually to your workflow configuration add a job like this:

```yml
jobs:
  {name}:
    uses: futuredapp/.github/.github/workflows/{platform}-{runner}-{action}.yml@main
    secrets:
      # Secrets to be passed to called workflow
      key: ${{ secrets.key }}
```

Name the job first and choose its platform, runner and action.
Check the reusable workflow file and pass alll the required secrets to it.
All the available reusable workflows are listed in the following table.

### Available workflows

|Platform       |Runner      |Action  |File                                                                                 |Description                                                           |
|:--------------|:-----------|:-------|:------------------------------------------------------------------------------------|:---------------------------------------------------------------------|
|Universal      |Cloud       |Backup  |[`universal-cloud-backup`](.github/workflows/universal-cloud-backup.yml)             |Backups currently checked out ref to a remote repository.             |
|Universal      |Self-hosted |Backup  |[`universal-selfhosted-backup`](.github/workflows/universal-selfhosted-backup.yml)   |Backups currently checked out ref to a remote repository.             |
|iOS            |Self-hosted |Test    |[`ios-selfhosted-test`](.github/workflows/ios-selfhosted-test.yml)                   |Lints and tests the PR.                                               |
|iOS            |Self-hosted |Build   |[`ios-selfhosted-build`](.github/workflows/ios-selfhosted-build.yml)                 |Creates enterprise release build and submits the build to Futured App Store Connect. |
|iOS            |Self-hosted |Release |[`ios-selfhosted-release`](.github/workflows/ios-selfhosted-release.yml)             |Creates release build and submits it to App Store Connect.            |
|iOS            |Cloud       |Test    |[`ios-cloud-test`](.github/workflows/ios-cloud-test.yml)                             |Lints and tests the PR.                                               |
|iOS            |Cloud       |Build   |[`ios-cloud-build`](.github/workflows/ios-cloud-build.yml)                           |Creates enterprise release build and submits the build to App Center. |
|iOS            |Cloud       |Release |[`ios-cloud-release`](.github/workflows/ios-cloud-release.yml)                       |Creates release build and submits it to App Store Connect.            |
|iOS (KMP)      |Self-hosted |Test    |[`ios-kmp-selfhosted-test`](.github/workflows/ios-kmp-selfhosted-test.yml)           |Lints and tests the PR.                                               |
|iOS (KMP)      |Self-hosted |Build   |[`ios-kmp-selfhosted-build`](.github/workflows/ios-kmp-selfhosted-build.yml)         |Creates enterprise release build and submits the build to Futured App Store Connect. |
|iOS (KMP)      |Self-hosted |Release |[`ios-kmp-selfhosted-release`](.github/workflows/ios-kmp-selfhosted-release.yml)     |Creates release build and submits it to App Store Connect.            |

## Contributors

All contributions are welcome!

Current maintainer is [Matěj Kašpar Jirásek](https://github.com/mkj-is), <matej.jirasek@futured.app>.

## License

Content of this repository is available under the MIT license. See the [LICENSE file](LICENSE) for more information.
