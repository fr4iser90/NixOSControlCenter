"""Pick harness by settings / template / coding tags."""

from __future__ import annotations

import os
from typing import Any, Iterable

from .dsh import DshHarness
from .native import NativeHarness
from .qwen import QwenHarness
from .types import HarnessBackend, HarnessInfo

CODING_TAGS = frozenset(
    {
        "coding",
        "git",
        "github",
        "code-review",
        "code",
        "docs",
        "agents",
        "skills",
        "review",
    }
)

_VALID = frozenset({"native", "qwen", "dsh"})


def _env_harness(name: str, default: str) -> str:
    raw = (os.environ.get(name) or default).strip().lower()
    return raw if raw in _VALID else default


def default_harness_name() -> str:
    return _env_harness("NCC_ASSISTANT_HARNESS", "native")


def coding_harness_name() -> str:
    """Harness for coding/git-tagged work. ``auto`` probes installed backends."""
    raw = (os.environ.get("NCC_ASSISTANT_CODING_HARNESS") or "auto").strip().lower()
    if raw in _VALID:
        return raw
    # auto: honor default if already external; else pick first installed
    default = default_harness_name()
    if default in ("qwen", "dsh"):
        return default
    q = QwenHarness().probe()
    if q.available:
        return "qwen"
    d = DshHarness().probe()
    if d.available:
        return "dsh"
    return default


def resolve_harness_name(
    *,
    template_harness: str | None = None,
    tags: Iterable[str] | None = None,
    force: str | None = None,
) -> str:
    """
    Resolution order:
    1. ``force`` (CLI / companion override)
    2. template ``harness`` field
    3. if tags intersect CODING_TAGS → coding harness
    4. default harness
    """
    if force and force.strip().lower() in _VALID:
        return force.strip().lower()
    if template_harness and str(template_harness).strip().lower() in _VALID:
        return str(template_harness).strip().lower()
    tagset = {str(t).strip().lower() for t in (tags or []) if t}
    if tagset & CODING_TAGS:
        return coding_harness_name()
    return default_harness_name()


def get_harness(name: str | None = None) -> HarnessBackend:
    key = (name or default_harness_name()).strip().lower()
    if key == "qwen":
        return QwenHarness()
    if key == "dsh":
        return DshHarness()
    return NativeHarness()


def available_harnesses() -> list[HarnessInfo]:
    return [get_harness(n).probe() for n in ("native", "qwen", "dsh")]


def looks_like_coding_goal(text: str) -> bool:
    low = (text or "").lower()
    needles = (
        "git ",
        "github",
        "pull request",
        "code review",
        "commit",
        "refactor",
        "agents.md",
        "skill",
        "repository",
        "repo ",
    )
    return any(n in low for n in needles)
