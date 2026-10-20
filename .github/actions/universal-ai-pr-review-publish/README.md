# Publish AI PR review

Publishes the result of an AI PR review run by [`universal-cloud-ai-pr-review`](../../workflows/universal-cloud-ai-pr-review.yml). It runs in a job that holds the write token and never checks out PR code.

1. Creates the `needs-human` and `feature-complete` labels when the repository does not have them yet.
2. When `risk.level` in the result JSON is `high`, adds `needs-human` and requests a review from `reviewer` first, so a failure there cannot leave a fresh review comment behind.
3. Creates or updates **one** PR comment written by `github-actions[bot]`, whose first line starts with `<!-- ai-pr-review sha=`. Comments from anyone else are never touched.
4. When the review produced no result, keeps one failure note with the run link and fails the step. A later successful review deletes the note.

## Usage

```yaml
- uses: futuredapp/.github/.github/actions/universal-ai-pr-review-publish@main
  with:
    github_token: ${{ github.token }}
    pr_number: 42
    result_file: ${{ runner.temp }}/ai-review-out/result.json
    body_file: ${{ runner.temp }}/ai-review-out/comment.md
    reviewer: some-login
```

The job needs `pull-requests: write` and `issues: write`. A team reviewer (`org/team`) needs a token that can read organisation members, which `GITHUB_TOKEN` cannot; use a login.
