"""Named secrets for agent templates / MCP (never in systemConfig)."""

from __future__ import annotations

import json
import os
import re
import stat
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from .paths import secrets_file

_NAME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9_-]{0,63}$")


@dataclass
class SecretMeta:
    name: str
    label: str = ""
    created: str = ""
    updated: str = ""

    def to_public_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "label": self.label or self.name,
            "created": self.created,
            "updated": self.updated,
            "has_value": True,
        }


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _load_raw() -> dict[str, Any]:
    path = secrets_file()
    if not path.is_file():
        return {"secrets": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"secrets": {}}
    if not isinstance(data, dict):
        return {"secrets": {}}
    secrets = data.get("secrets")
    if not isinstance(secrets, dict):
        data["secrets"] = {}
    return data


def _save_raw(data: dict[str, Any]) -> None:
    path = secrets_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    try:
        os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)
    except OSError:
        pass


def validate_secret_name(name: str) -> str:
    n = (name or "").strip()
    if not _NAME_RE.match(n):
        raise ValueError(
            "Secret name must start with a letter and use only "
            "letters, digits, '_' or '-' (max 64 chars)."
        )
    return n


def list_secrets() -> list[SecretMeta]:
    raw = _load_raw().get("secrets") or {}
    out: list[SecretMeta] = []
    for name, entry in sorted(raw.items()):
        if not isinstance(entry, dict):
            continue
        value = entry.get("value")
        if not isinstance(value, str) or not value.strip():
            continue
        out.append(
            SecretMeta(
                name=str(name),
                label=str(entry.get("label") or name),
                created=str(entry.get("created") or ""),
                updated=str(entry.get("updated") or ""),
            )
        )
    return out


def has_secret(name: str) -> bool:
    try:
        n = validate_secret_name(name)
    except ValueError:
        return False
    entry = (_load_raw().get("secrets") or {}).get(n)
    if not isinstance(entry, dict):
        return False
    value = entry.get("value")
    return isinstance(value, str) and bool(value.strip())


def get_secret_value(name: str) -> str | None:
    """Return secret value or None. Callers must not log/print the value."""
    try:
        n = validate_secret_name(name)
    except ValueError:
        return None
    entry = (_load_raw().get("secrets") or {}).get(n)
    if not isinstance(entry, dict):
        return None
    value = entry.get("value")
    if isinstance(value, str) and value.strip():
        return value
    return None


def set_secret(name: str, value: str, *, label: str | None = None) -> SecretMeta:
    n = validate_secret_name(name)
    v = (value or "").strip()
    if not v:
        raise ValueError("Secret value must not be empty.")
    data = _load_raw()
    secrets = data.setdefault("secrets", {})
    now = _now()
    prev = secrets.get(n) if isinstance(secrets.get(n), dict) else {}
    created = str(prev.get("created") or now) if isinstance(prev, dict) else now
    lbl = (label or "").strip() or (
        str(prev.get("label") or n) if isinstance(prev, dict) else n
    )
    secrets[n] = {
        "label": lbl,
        "value": v,
        "created": created,
        "updated": now,
    }
    _save_raw(data)
    return SecretMeta(name=n, label=lbl, created=created, updated=now)


def delete_secret(name: str) -> bool:
    try:
        n = validate_secret_name(name)
    except ValueError:
        return False
    data = _load_raw()
    secrets = data.get("secrets") or {}
    if n not in secrets:
        return False
    del secrets[n]
    data["secrets"] = secrets
    _save_raw(data)
    return True


def resolve_secret_refs(mapping: dict[str, str]) -> dict[str, str]:
    """
    Expand envFromSecrets values like '{{secret.github_token}}' → real values.
    Missing secrets raise ValueError.
    """
    out: dict[str, str] = {}
    for env_key, ref in mapping.items():
        raw = str(ref or "").strip()
        m = re.fullmatch(r"\{\{\s*secret\.([a-zA-Z][a-zA-Z0-9_-]*)\s*\}\}", raw)
        if m:
            name = m.group(1)
            value = get_secret_value(name)
            if value is None:
                raise ValueError(f"Missing secret: {name}")
            out[str(env_key)] = value
        elif raw.startswith("{{") and raw.endswith("}}"):
            raise ValueError(f"Unsupported secret placeholder: {raw}")
        else:
            # Literal env value allowed
            out[str(env_key)] = raw
    return out
