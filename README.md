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

|Platform |Runner      |Action     |File                                                                              |Description                                                           |
|:--------|:-----------|:----------|:---------------------------------------------------------------------------------|:---------------------------------------------------------------------|
|iOS      |Cloud       |Test       |`[ios-cloud-test](../.github/workflows/ios-cloud-test.yml)`                       |Lints and tests the PR.                                               |
|iOS      |Cloud       |Build      |`[ios-cloud-build](../.github/workflows/ios-cloud-build.yml)`                     |Creates enterprise release build and submits the build to App Center. |
|iOS      |Cloud       |Distribute |`[ios-cloud-distribute](../.github/workflows/ios-cloud-distribute.yml)`           |Creates release build and submits it to App Store Connect.            |
|iOS      |Self-hosted |Test       |`[ios-selfhosted-test](../.github/workflows/ios-selfhosted-test.yml)`             |Lints and tests the PR.                                               |
|iOS      |Self-hosted |Build      |`[ios-selfhosted-build](../.github/workflows/ios-selfhosted-build.yml)`           |Creates enterprise release build and submits the build to App Center. |
|iOS      |Self-hosted |Distribute |`[ios-selfhosted-distribute](../.github/workflows/ios-selfhosted-distribute.yml)` |Creates release build and submits it to App Store Connect.            |
