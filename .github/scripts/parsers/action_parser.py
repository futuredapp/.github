"""Parser for composite GitHub Actions (action.yml) files."""

from __future__ import annotations

from pathlib import Path

import yaml

from .types import ActionSpec, InputSpec, OutputSpec


def parse_action(path: str | Path) -> ActionSpec:
    """Parse a composite action YAML file into an ActionSpec."""
    path = Path(path)
    with open(path) as f:
        data = yaml.safe_load(f)

    name = data.get("name", path.parent.name)
    description = data.get("description", "")

    inputs = _parse_inputs(data.get("inputs") or {})
    outputs = _parse_outputs(data.get("outputs") or {})

    return ActionSpec(
        name=name,
        description=description,
        source_path=str(path),
        inputs=inputs,
        outputs=outputs,
    )


def _parse_inputs(raw: dict) -> list[InputSpec]:
    inputs = []
    for name, spec in raw.items():
        spec = spec or {}
        default = spec.get("default")
        inputs.append(
            InputSpec(
                name=name,
                description=spec.get("description", ""),
                type=spec.get("type", "string"),
                required=spec.get("required", False),
                default=str(default) if default is not None else None,
            )
        )
    return inputs


def _parse_outputs(raw: dict) -> list[OutputSpec]:
    outputs = []
    for name, spec in raw.items():
        spec = spec or {}
        outputs.append(
            OutputSpec(
                name=name,
                description=spec.get("description", ""),
            )
        )
    return outputs
