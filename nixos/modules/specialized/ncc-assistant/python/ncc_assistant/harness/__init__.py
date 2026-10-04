"""Swappable agent harness backends (native / qwen / dsh)."""

from __future__ import annotations

from .resolve import (
    CODING_TAGS,
    available_harnesses,
    get_harness,
    resolve_harness_name,
)
from .types import HarnessBackend, HarnessInfo

__all__ = [
    "CODING_TAGS",
    "HarnessBackend",
    "HarnessInfo",
    "available_harnesses",
    "get_harness",
    "resolve_harness_name",
]
