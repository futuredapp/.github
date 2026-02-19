"""Renders parsed specs + enrichment results into markdown files via Jinja2."""

from __future__ import annotations

import os
import re
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from scripts.config import ACTIONS, CATEGORY_LABELS, WORKFLOWS
from scripts.enrichers.base import EnrichmentResult
from scripts.parsers.types import ActionSpec, InputSpec, WorkflowSpec


def _build_env(templates_dir: str | Path) -> Environment:
    return Environment(
        loader=FileSystemLoader(str(templates_dir)),
        keep_trailing_newline=True,
        trim_blocks=True,
        lstrip_blocks=True,
    )


def _usage_placeholder(inp: InputSpec) -> str:
    """Generate a placeholder value for the usage snippet."""
    if inp.default is not None:
        return inp.default
    type_map = {
        "boolean": "true",
        "number": "0",
    }
    return type_map.get(inp.type, "'...'")


def _resolve_action_link(uses_ref: str, from_output_path: str) -> dict | None:
    """Resolve a uses: reference to a cross-link if it's an internal action."""
    # Match futuredapp/.github/.github/actions/<name>@...
    match = re.match(
        r"futuredapp/\.github/\.github/actions/([^@]+)@", uses_ref
    )
    if not match:
        # Also match internal workflow references
        wf_match = re.match(
            r"futuredapp/\.github/\.github/workflows/([^@]+)@", uses_ref
        )
        if not wf_match:
            return None
        wf_file = wf_match.group(1)
        # Find matching workflow config
        for _key, cfg in WORKFLOWS.items():
            if cfg["source"].endswith(wf_file):
                rel = os.path.relpath(cfg["output"], os.path.dirname(from_output_path))
                return {"name": cfg["title"], "link": rel}
        return None

    action_name = match.group(1)
    for _key, cfg in ACTIONS.items():
        if action_name in cfg["source"]:
            rel = os.path.relpath(cfg["output"], os.path.dirname(from_output_path))
            return {"name": cfg["title"], "link": rel}
    return None


def render_workflow(
    spec: WorkflowSpec,
    config: dict,
    enrichments: list[EnrichmentResult],
    templates_dir: str | Path,
    output_base: str | Path,
    ref: str = "main",
) -> Path:
    """Render a workflow spec to a markdown file."""
    env = _build_env(templates_dir)
    template = env.get_template("workflow.md.j2")

    # Prepare inputs with usage placeholders
    inputs = []
    required_inputs = []
    for inp in spec.inputs:
        inp_dict = {
            "name": inp.name,
            "type": inp.type,
            "required": inp.required,
            "default": inp.default,
            "description": inp.description,
            "usage_placeholder": _usage_placeholder(inp),
        }
        inputs.append(inp_dict)
        if inp.required:
            required_inputs.append(inp_dict)

    required_secrets = [s for s in spec.secrets if s.required]

    # Resolve internal action cross-links
    internal_actions: list[dict] = []
    seen_actions: set[str] = set()
    for _job_name, job_info in spec.jobs.items():
        for uses_ref in job_info.get("uses", []):
            link = _resolve_action_link(uses_ref, config["output"])
            if link and link["name"] not in seen_actions:
                internal_actions.append(link)
                seen_actions.add(link["name"])

    # Merge enrichment results
    enrichment_parts: list[str] = []
    for er in enrichments:
        if er.additional_description:
            enrichment_parts.append(er.additional_description)
        if er.usage_tips:
            enrichment_parts.append(er.usage_tips)
    enrichment_text = "\n\n".join(enrichment_parts) if enrichment_parts else ""

    # Generate a sensible job name for the usage snippet
    usage_job_name = config.get("title", "build").lower().replace(" ", "-")
    usage_job_name = re.sub(r"[^a-z0-9-]", "", usage_job_name)

    rendered = template.render(
        title=config["title"],
        source_path=config["source"],
        runner=config.get("runner", ""),
        deprecated=config.get("deprecated", False),
        deprecated_message=config.get("deprecated_message", ""),
        not_reusable=config.get("not_reusable", False),
        spec=spec,
        inputs=inputs,
        required_inputs=required_inputs,
        secrets=spec.secrets,
        required_secrets=required_secrets,
        outputs=spec.outputs,
        internal_actions=internal_actions,
        enrichment=enrichment_text,
        usage_job_name=usage_job_name,
        ref=ref,
    )

    output_path = Path(output_base) / config["output"]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")
    return output_path


def render_action(
    spec: ActionSpec,
    config: dict,
    enrichments: list[EnrichmentResult],
    templates_dir: str | Path,
    output_base: str | Path,
    ref: str = "main",
) -> Path:
    """Render an action spec to a markdown file."""
    env = _build_env(templates_dir)
    template = env.get_template("action.md.j2")

    inputs = []
    required_inputs = []
    for inp in spec.inputs:
        inp_dict = {
            "name": inp.name,
            "type": inp.type,
            "required": inp.required,
            "default": inp.default,
            "description": inp.description,
            "usage_placeholder": _usage_placeholder(inp),
        }
        inputs.append(inp_dict)
        if inp.required:
            required_inputs.append(inp_dict)

    # Merge enrichment results
    enrichment_parts: list[str] = []
    for er in enrichments:
        if er.additional_description:
            enrichment_parts.append(er.additional_description)
        if er.usage_tips:
            enrichment_parts.append(er.usage_tips)
    enrichment_text = "\n\n".join(enrichment_parts) if enrichment_parts else ""

    # Action path (e.g. actions/android-setup-environment)
    action_path = str(Path(config["source"]).parent)

    rendered = template.render(
        title=config["title"],
        source_path=config["source"],
        spec=spec,
        inputs=inputs,
        required_inputs=required_inputs,
        outputs=spec.outputs,
        enrichment=enrichment_text,
        action_path=action_path,
        ref=ref,
    )

    output_path = Path(output_base) / config["output"]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")
    return output_path


def render_index(
    title: str,
    description: str,
    items: list[dict],
    templates_dir: str | Path,
    output_path: str | Path,
) -> Path:
    """Render a category index page."""
    env = _build_env(templates_dir)
    template = env.get_template("index.md.j2")

    rendered = template.render(
        title=title,
        description=description,
        items=items,
    )

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")
    return output_path
