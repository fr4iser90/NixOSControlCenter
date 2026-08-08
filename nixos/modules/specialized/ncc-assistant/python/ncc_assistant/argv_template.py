"""Expand domain-tool argv templates without a shell."""

from __future__ import annotations

import re
from typing import Any

_PLACEHOLDER = re.compile(r"^\{\{(\w+)(\?)?\}\}$")
_ANY_PLACEHOLDER = re.compile(r"\{\{(\w+)(\?)?\}\}")
# Bare CLI flag when arg is truthy: {{flag:system}} → --system
_FLAG = re.compile(r"^\{\{flag:(\w+)\}\}$")


def apply_schema_defaults(
    schema: dict[str, Any] | None, args: dict[str, Any]
) -> dict[str, Any]:
    out = dict(args)
    if not schema:
        return out
    props = schema.get("properties") or {}
    if not isinstance(props, dict):
        return out
    for key, spec in props.items():
        if key in out or not isinstance(spec, dict):
            continue
        if "default" in spec:
            out[key] = spec["default"]
    return out


def _fmt(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def _truthy(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in ("1", "true", "yes", "on")


def _expand_token(part: str, args: dict[str, Any]) -> str | None:
    """
    Expand placeholders in one argv token.

    Returns ``None`` to omit the token (optional placeholder missing).
    """
    m_flag = _FLAG.match(part)
    if m_flag:
        key = m_flag.group(1)
        if _truthy(args.get(key)):
            return f"--{key.replace('_', '-')}"
        return None

    m_full = _PLACEHOLDER.match(part)
    if m_full:
        key, optional = m_full.group(1), m_full.group(2) == "?"
        if key not in args or args[key] is None:
            if optional:
                return None
            raise ValueError(f"Missing required argument: {key}")
        return _fmt(args[key])

    skip = False

    def repl(m: re.Match[str]) -> str:
        nonlocal skip
        key, optional = m.group(1), m.group(2) == "?"
        if key not in args or args[key] is None:
            if optional:
                skip = True
                return ""
            raise ValueError(f"Missing required argument: {key}")
        return _fmt(args[key])

    out = _ANY_PLACEHOLDER.sub(repl, part)
    if skip:
        return None
    return out


def expand_argv(template: list[str], args: dict[str, Any]) -> list[str]:
    """
    Expand ``{{key}}`` (required) and ``{{key?}}`` (optional).

    - Full-token optional missing → token omitted.
    - Inline ``environment={{environment?}}`` missing → whole token omitted.
    - ``--flag`` followed by missing ``{{key?}}`` → both omitted.
    """
    out: list[str] = []
    i = 0
    n = len(template)
    while i < n:
        part = template[i]
        # Only treat as --flag VALUE when next token is a {{value}} placeholder
        # (not {{flag:…}} and not a literal like --json).
        if part.startswith("--") and i + 1 < n:
            nxt_raw = template[i + 1]
            if _PLACEHOLDER.match(nxt_raw) and not _FLAG.match(nxt_raw):
                nxt = _expand_token(nxt_raw, args)
                if nxt is None:
                    i += 2
                    continue
                out.append(part)
                out.append(nxt)
                i += 2
                continue

        expanded = _expand_token(part, args)
        if expanded is not None:
            out.append(expanded)
        i += 1
    return out
