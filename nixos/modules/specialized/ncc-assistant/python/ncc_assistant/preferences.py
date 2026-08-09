"""User preferences (last model / provider) under ~/.config/ncc-assistant/."""

from __future__ import annotations

import json
import os
from typing import Any

from .paths import preferences_file


def load_preferences() -> dict[str, Any]:
    path = preferences_file()
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def save_preferences(data: dict[str, Any]) -> None:
    path = preferences_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    merged = load_preferences()
    merged.update({k: v for k, v in data.items() if v is not None})
    path.write_text(
        json.dumps(merged, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def get_last_model() -> str | None:
    raw = load_preferences().get("last_model")
    if isinstance(raw, str) and raw.strip():
        return raw.strip()
    return None


def get_last_provider_id() -> str | None:
    raw = load_preferences().get("last_provider_id")
    if isinstance(raw, str) and raw.strip():
        return raw.strip()
    return None


def set_last_model(model: str | None) -> None:
    if model:
        save_preferences({"last_model": model})


def set_last_provider(provider_id: str | None, endpoint: str | None = None) -> None:
    payload: dict[str, Any] = {}
    if provider_id:
        payload["last_provider_id"] = provider_id
    if endpoint:
        payload["last_endpoint"] = endpoint
    if payload:
        save_preferences(payload)


def apply_startup_preferences(settings: Any) -> Any:
    """Apply last provider / model from preferences (Nix model env wins if set)."""
    from dataclasses import replace

    from .auth import with_cached_credentials
    from .providers import apply_provider_settings, ensure_seeded, get_provider

    ensure_seeded()
    nix_model = os.environ.get("NCC_ASSISTANT_MODEL", "").strip()
    model = settings.model
    if not nix_model:
        last = get_last_model()
        if last:
            model = last

    pid = get_last_provider_id()
    if pid:
        prov = get_provider(pid)
        if prov is not None:
            settings = apply_provider_settings(settings, prov)
            settings = replace(settings, model=model)
            return with_cached_credentials(settings)

    if model != settings.model:
        settings = replace(settings, model=model)
    return with_cached_credentials(settings)
