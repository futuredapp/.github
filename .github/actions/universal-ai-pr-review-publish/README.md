# Publish AI PR review

Publishes the result of an AI PR review run by [`universal-cloud-ai-pr-review`](../../workflows/universal-cloud-ai-pr-review.yml):

- Creates or updates **one** PR comment, found by its first line (`<!-- ai-pr-review -->`). Re-runs edit it instead of adding comments.
- When `risk.level` in the result JSON is `high`, adds the `needs-human` label and requests a review from `reviewer` (a login, or `org/team`).
- Creates the `needs-human` and `feature-complete` labels when the repository does not have them yet.
- When the review produced no result, posts a short failure note with the run link and fails the step.

## Usage

```yaml
- uses: futuredapp/.github/.github/actions/universal-ai-pr-review-publish@main
  with:
    github_token: ${{ github.token }}
    pr_number: 42
    result_file: ${{ runner.temp }}/ai-review/result.json
    body_file: ${{ runner.temp }}/ai-review/comment.md
    reviewer: some-login
```

The job needs `pull-requests: write` and `issues: write`.
