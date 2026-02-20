"""Shared dataclasses and helpers for parsed workflow and action specifications."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class InputSpec:
    name: str
    description: str
    type: str = "string"
    required: bool = False
    default: str | None = None


@dataclass
class SecretSpec:
    name: str
    description: str
    required: bool = False


@dataclass
class OutputSpec:
    name: str
    description: str


@dataclass
class WorkflowSpec:
    name: str
    source_path: str
    inputs: list[InputSpec] = field(default_factory=list)
    secrets: list[SecretSpec] = field(default_factory=list)
    outputs: list[OutputSpec] = field(default_factory=list)
    jobs: dict[str, dict] = field(default_factory=dict)


@dataclass
class ActionSpec:
    name: str
    description: str
    source_path: str
    inputs: list[InputSpec] = field(default_factory=list)
    outputs: list[OutputSpec] = field(default_factory=list)


def parse_inputs(raw: dict) -> list[InputSpec]:
    """Parse a raw inputs dict into a list of InputSpec."""
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


def parse_outputs(raw: dict) -> list[OutputSpec]:
    """Parse a raw outputs dict into a list of OutputSpec."""
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
