"""Parser for composite GitHub Actions (action.yml) files."""

from __future__ import annotations

from pathlib import Path

import yaml

from .types import ActionSpec, parse_inputs, parse_outputs


def parse_action(path: str | Path) -> ActionSpec:
    """Parse a composite action YAML file into an ActionSpec."""
    path = Path(path)
    with open(path) as f:
        data = yaml.safe_load(f)
    data = data or {}

    name = data.get("name", path.parent.name)
    description = data.get("description", "")

    inputs = parse_inputs(data.get("inputs") or {})
    outputs = parse_outputs(data.get("outputs") or {})

    return ActionSpec(
        name=name,
        description=description,
        source_path=str(path),
        inputs=inputs,
        outputs=outputs,
    )
