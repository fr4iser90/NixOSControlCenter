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


def get_trace_density() -> str:
    raw = load_preferences().get("trace_density")
    if isinstance(raw, str) and raw.strip().lower() in ("compact", "comfortable"):
        return raw.strip().lower()
    return "comfortable"


def set_trace_density(density: str) -> None:
    d = (density or "").strip().lower()
    if d in ("compact", "comfortable"):
        save_preferences({"trace_density": d})


def get_expand_thinking_while_streaming() -> bool:
    return bool(load_preferences().get("expand_thinking_while_streaming"))


def set_expand_thinking_while_streaming(enabled: bool) -> None:
    save_preferences({"expand_thinking_while_streaming": bool(enabled)})


def get_default_harness_mode() -> str:
    raw = load_preferences().get("harness_mode")
    if isinstance(raw, str) and raw.strip().lower() in (
        "auto",
        "native",
        "qwen",
        "dsh",
    ):
        return raw.strip().lower()
    return "auto"


def set_default_harness_mode(mode: str) -> None:
    m = (mode or "").strip().lower()
    if m in ("auto", "native", "qwen", "dsh"):
        save_preferences({"harness_mode": m})


def get_active_workspace_id() -> str | None:
    raw = load_preferences().get("active_workspace_id")
    if isinstance(raw, str) and raw.strip():
        return raw.strip()
    return None


def set_active_workspace_id(workspace_id: str | None) -> None:
    if workspace_id and str(workspace_id).strip():
        save_preferences({"active_workspace_id": str(workspace_id).strip()})
    else:
        save_preferences({"active_workspace_id": ""})


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
