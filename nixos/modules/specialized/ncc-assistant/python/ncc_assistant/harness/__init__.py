"""Swappable agent harness backends (native / qwen / dsh)."""

from __future__ import annotations

from .resolve import (
    CODING_TAGS,
    available_harnesses,
    coding_harness_name,
    default_harness_name,
    get_harness,
    looks_like_coding_goal,
    resolve_harness_name,
)
from .types import HarnessBackend, HarnessInfo

__all__ = [
    "CODING_TAGS",
    "HarnessBackend",
    "HarnessInfo",
    "available_harnesses",
    "coding_harness_name",
    "default_harness_name",
    "get_harness",
    "looks_like_coding_goal",
    "resolve_harness_name",
]
