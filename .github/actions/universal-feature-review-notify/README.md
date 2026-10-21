# Feature review notify

After a build, finds the PRs merged in its commit range that carry the `feature-complete` label and posts one Slack message listing them, each with the text of its `## What to try` section. The person mentioned in the message installs the build and looks at the finished feature as a whole.

PRs are matched by their merge commit, so merge commits and squash merges both work. No labeled PR in the range means no message. Template placeholder comments (`<!-- … -->`) are left out of the quoted text.

## Usage

Most projects call the [`universal-cloud-feature-review-notify`](../../workflows/universal-cloud-feature-review-notify.yml) workflow as a second job after the build, with the build workflow's `from_commit` / `to_commit` outputs. As an action:

```yaml
- uses: futuredapp/.github/.github/actions/universal-feature-review-notify@main
  with:
    github_token: ${{ github.token }}
    from_commit: ${{ needs.build.outputs.from_commit }}
    to_commit: ${{ needs.build.outputs.to_commit }}
    slack_webhook_url: ${{ secrets.SLACK_WEBHOOK_FEATURE_REVIEW }}
    reviewer_mention: '<@U0123456>'
```

Without `slack_webhook_url` the message is printed to the log instead.
