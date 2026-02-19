"""Shared dataclasses for parsed workflow and action specifications."""

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
