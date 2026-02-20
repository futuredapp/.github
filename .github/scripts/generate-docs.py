#!/usr/bin/env python3
"""Generate documentation markdown files from workflow and action YAML specs.

Usage:
    python scripts/generate-docs.py [--enrich] [--ai-config PATH]

Pipeline:
    1. Load config registry
    2. Parse all workflow YAMLs + action YAMLs
    3. Run enricher pipeline (README enricher always; AI enricher if --enrich)
    4. Render markdown via Jinja2 templates
    5. Write generated .md files to docs/
    6. Generate category index pages
"""

from __future__ import annotations

import argparse
import os
import sys
from collections import defaultdict
from pathlib import Path

# Ensure the scripts package is importable
SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
sys.path.insert(0, str(ROOT_DIR))

from scripts.config import ACTIONS, CATEGORY_LABELS, WORKFLOWS
from scripts.enrichers.ai_enricher import AIEnricher
from scripts.enrichers.base import BaseEnricher, EnrichmentResult
from scripts.enrichers.readme_enricher import ReadmeEnricher
from scripts.parsers.action_parser import parse_action
from scripts.parsers.workflow_parser import parse_workflow
from scripts.renderers.markdown_renderer import (
    render_action,
    render_index,
    render_workflow,
)


def _run_enrichers(
    enrichers: list[BaseEnricher],
    spec: object,
    config: dict,
) -> list[EnrichmentResult]:
    """Run all enrichers in sequence, passing prior results forward."""
    results: list[EnrichmentResult] = []
    for enricher in enrichers:
        if enricher.can_enrich(spec, config):
            result = enricher.enrich(spec, config, results)
            results.append(result)
    return results


def _build_workflow_index_items(
    category: str,
    configs: list[tuple[str, dict]],
    specs: dict,
) -> list[dict]:
    """Build index items for workflows in a category."""
    items = []
    for key, cfg in configs:
        spec = specs.get(key)
        # Relative link from index to the workflow page
        filename = Path(cfg["output"]).name
        items.append(
            {
                "title": cfg["title"],
                "link": filename,
                "description": spec.name if spec else cfg["title"],
            }
        )
    return items


def _build_action_index_items(
    category: str,
    configs: list[tuple[str, dict]],
    specs: dict,
) -> list[dict]:
    """Build index items for actions in a category."""
    items = []
    for key, cfg in configs:
        spec = specs.get(key)
        filename = Path(cfg["output"]).name
        items.append(
            {
                "title": cfg["title"],
                "link": filename,
                "description": spec.description if spec else cfg["title"],
            }
        )
    return items


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate documentation site")
    parser.add_argument(
        "--enrich",
        action="store_true",
        help="Enable AI enricher (requires AI_DOCS_API_KEY env var)",
    )
    parser.add_argument(
        "--ai-config",
        type=str,
        default=None,
        help="Path to AI enricher configuration JSON",
    )
    parser.add_argument(
        "--ref",
        type=str,
        default="main",
        help="Git ref for usage snippets (e.g. 'main' or '2.1.0')",
    )
    args = parser.parse_args()

    templates_dir = SCRIPT_DIR / "templates"

    # Initialize enrichers
    enrichers: list[BaseEnricher] = [
        ReadmeEnricher(ROOT_DIR),
        AIEnricher(enabled=args.enrich, config_path=args.ai_config),
    ]

    # -------------------------------------------------------------------
    # Parse all workflow YAML files
    # -------------------------------------------------------------------
    print("Parsing workflows...")
    workflow_specs = {}
    for key, cfg in WORKFLOWS.items():
        source = ROOT_DIR / cfg["source"]
        if not source.exists():
            print(f"  WARNING: {source} not found, skipping {key}")
            continue
        spec = parse_workflow(source)
        workflow_specs[key] = spec
        print(f"  Parsed: {key} ({spec.name})")

    # -------------------------------------------------------------------
    # Parse all action YAML files
    # -------------------------------------------------------------------
    print("\nParsing actions...")
    action_specs = {}
    for key, cfg in ACTIONS.items():
        source = ROOT_DIR / cfg["source"]
        if not source.exists():
            print(f"  WARNING: {source} not found, skipping {key}")
            continue
        spec = parse_action(source)
        action_specs[key] = spec
        print(f"  Parsed: {key} ({spec.name})")

    # -------------------------------------------------------------------
    # Render workflow pages
    # -------------------------------------------------------------------
    print("\nRendering workflow pages...")
    for key, cfg in WORKFLOWS.items():
        spec = workflow_specs.get(key)
        if not spec:
            continue
        enrichments = _run_enrichers(enrichers, spec, cfg)
        path = render_workflow(spec, cfg, enrichments, templates_dir, ROOT_DIR, ref=args.ref)
        print(f"  Written: {path.relative_to(ROOT_DIR)}")

    # -------------------------------------------------------------------
    # Render action pages
    # -------------------------------------------------------------------
    print("\nRendering action pages...")
    for key, cfg in ACTIONS.items():
        spec = action_specs.get(key)
        if not spec:
            continue
        enrichments = _run_enrichers(enrichers, spec, cfg)
        path = render_action(spec, cfg, enrichments, templates_dir, ROOT_DIR, ref=args.ref)
        print(f"  Written: {path.relative_to(ROOT_DIR)}")

    # -------------------------------------------------------------------
    # Generate category index pages
    # -------------------------------------------------------------------
    print("\nGenerating index pages...")

    # Group workflows by category
    wf_by_category: dict[str, list[tuple[str, dict]]] = defaultdict(list)
    for key, cfg in WORKFLOWS.items():
        wf_by_category[cfg["category"]].append((key, cfg))

    # Group actions by category
    act_by_category: dict[str, list[tuple[str, dict]]] = defaultdict(list)
    for key, cfg in ACTIONS.items():
        act_by_category[cfg["category"]].append((key, cfg))

    # Workflow category index pages
    for category, entries in wf_by_category.items():
        label = CATEGORY_LABELS.get(category, category.title())
        items = _build_workflow_index_items(category, entries, workflow_specs)
        index_path = ROOT_DIR / "docs" / "workflows" / category / "index.md"
        render_index(
            title=f"{label} Workflows",
            description=f"Reusable GitHub Actions workflows for {label} projects.",
            items=items,
            templates_dir=templates_dir,
            output_path=index_path,
        )
        print(f"  Written: {index_path.relative_to(ROOT_DIR)}")

    # Action category index pages
    for category, entries in act_by_category.items():
        label = CATEGORY_LABELS.get(category, category.title())
        items = _build_action_index_items(category, entries, action_specs)
        index_path = ROOT_DIR / "docs" / "actions" / category / "index.md"
        render_index(
            title=f"{label} Actions",
            description=f"Composite GitHub Actions for {label} projects.",
            items=items,
            templates_dir=templates_dir,
            output_path=index_path,
        )
        print(f"  Written: {index_path.relative_to(ROOT_DIR)}")

    # Top-level workflow index
    all_wf_items = []
    wf_categories = [c for c in CATEGORY_LABELS if c in wf_by_category]
    for category in wf_categories:
        label = CATEGORY_LABELS.get(category, category.title())
        all_wf_items.append(
            {
                "title": f"{label} Workflows",
                "link": f"{category}/index.md",
                "description": f"{len(wf_by_category[category])} workflow(s)",
            }
        )
    render_index(
        title="Workflows",
        description="All reusable GitHub Actions workflows organized by platform.",
        items=all_wf_items,
        templates_dir=templates_dir,
        output_path=ROOT_DIR / "docs" / "workflows" / "index.md",
    )
    print(f"  Written: docs/workflows/index.md")

    # Top-level action index
    all_act_items = []
    act_categories = [c for c in CATEGORY_LABELS if c in act_by_category]
    for category in act_categories:
        label = CATEGORY_LABELS.get(category, category.title())
        all_act_items.append(
            {
                "title": f"{label} Actions",
                "link": f"{category}/index.md",
                "description": f"{len(act_by_category[category])} action(s)",
            }
        )
    render_index(
        title="Actions",
        description="All composite GitHub Actions organized by platform.",
        items=all_act_items,
        templates_dir=templates_dir,
        output_path=ROOT_DIR / "docs" / "actions" / "index.md",
    )
    print(f"  Written: docs/actions/index.md")

    # -------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------
    total_wf = len(workflow_specs)
    total_act = len(action_specs)
    print(f"\nDone! Generated {total_wf} workflow pages + {total_act} action pages.")


if __name__ == "__main__":
    main()
