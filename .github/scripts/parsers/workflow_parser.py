"""Parser for reusable GitHub Actions workflow files (on.workflow_call)."""

from __future__ import annotations

from pathlib import Path

import yaml

from .types import InputSpec, OutputSpec, SecretSpec, WorkflowSpec, parse_inputs, parse_outputs


def parse_workflow(path: str | Path) -> WorkflowSpec:
    """Parse a reusable workflow YAML file into a WorkflowSpec."""
    path = Path(path)
    with open(path) as f:
        data = yaml.safe_load(f)
    data = data or {}

    name = data.get("name", path.stem)

    # Extract workflow_call trigger definition
    on_block = data.get("on") or data.get(True) or {}
    workflow_call = {}
    if isinstance(on_block, dict):
        workflow_call = on_block.get("workflow_call", {}) or {}

    inputs = parse_inputs(workflow_call.get("inputs") or {})
    secrets = _parse_secrets(workflow_call.get("secrets") or {})
    outputs = parse_outputs(workflow_call.get("outputs") or {})
    jobs = _parse_jobs(data.get("jobs") or {})

    return WorkflowSpec(
        name=name,
        source_path=str(path),
        inputs=inputs,
        secrets=secrets,
        outputs=outputs,
        jobs=jobs,
    )


def _parse_secrets(raw: dict) -> list[SecretSpec]:
    secrets = []
    for name, spec in raw.items():
        spec = spec or {}
        secrets.append(
            SecretSpec(
                name=name,
                description=spec.get("description", ""),
                required=spec.get("required", False),
            )
        )
    return secrets


def _parse_jobs(raw: dict) -> dict[str, dict]:
    jobs = {}
    for job_name, job_spec in raw.items():
        job_spec = job_spec or {}
        job_info: dict = {
            "runs-on": job_spec.get("runs-on", ""),
        }

        # Collect all 'uses' references from steps and job-level reuse
        uses_refs: list[str] = []
        if "uses" in job_spec:
            uses_refs.append(job_spec["uses"])

        for step in job_spec.get("steps") or []:
            if "uses" in step:
                uses_refs.append(step["uses"])

        if uses_refs:
            job_info["uses"] = uses_refs

        jobs[job_name] = job_info
    return jobs
