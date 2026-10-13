# Review gate

Sets a commit status (default context `review-gate`) on the PR head. Make it a required status check in the branch ruleset to replace a mandatory approval with:

1. **The AI review ran** — the PR has a comment starting with the marker (`<!-- ai-pr-review -->`) posted by [`universal-cloud-ai-pr-review`](../../workflows/universal-cloud-ai-pr-review.yml). It counts for every later commit, so pushes after the review do not block the merge.
2. **High-risk PRs got a human approval** — when the PR carries the `needs-human` label, the latest decisive review of at least one reviewer other than the author must be `APPROVED`.

While a condition is unmet the status is `pending` with a description of what is missing.

It runs from [`universal-cloud-review-gate`](../../workflows/universal-cloud-review-gate.yml) on PR and review events, and at the end of every AI review run. The AI review run is needed because a label or comment created with `GITHUB_TOKEN` does not trigger other workflows.

## Usage

```yaml
- uses: futuredapp/.github/.github/actions/universal-review-gate@main
  with:
    github_token: ${{ github.token }}
    pr_number: ${{ github.event.pull_request.number }}
    head_sha: ${{ github.event.pull_request.head.sha }}
```

The job needs `statuses: write`, `pull-requests: read` and `issues: read`.
