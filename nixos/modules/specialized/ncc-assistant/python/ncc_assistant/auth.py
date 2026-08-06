"""Interactive / cached API auth for ncc ai (never store keys in systemConfig)."""

from __future__ import annotations

import json
import os
import stat
import sys
from dataclasses import replace
from getpass import getpass
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import httpx

from .config import Settings


def credentials_path() -> Path:
    xdg = os.environ.get("XDG_CONFIG_HOME")
    base = Path(xdg) if xdg else Path.home() / ".config"
    return base / "ncc-assistant" / "credentials.json"


def _endpoint_key(endpoint: str) -> str:
    return endpoint.rstrip("/")


def load_cached_auth(endpoint: str) -> tuple[str | None, str | None]:
    path = credentials_path()
    if not path.is_file():
        return None, None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None, None
    entry = data.get(_endpoint_key(endpoint)) or data.get(urlparse(endpoint).netloc)
    if not isinstance(entry, dict):
        return None, None
    key = entry.get("api_key") or entry.get("key")
    header = entry.get("header_name") or entry.get("api_header_name")
    if isinstance(key, str) and key.strip():
        return key.strip(), (header.strip() if isinstance(header, str) and header.strip() else None)
    return None, None


def save_cached_auth(endpoint: str, api_key: str, header_name: str | None) -> Path:
    path = credentials_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    data: dict[str, Any] = {}
    if path.is_file():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                data = {}
        except (OSError, json.JSONDecodeError):
            data = {}
    data[_endpoint_key(endpoint)] = {
        "api_key": api_key,
        "header_name": header_name,
    }
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    path.chmod(stat.S_IRUSR | stat.S_IWUSR)  # 0600
    return path


def probe_needs_auth(settings: Settings) -> bool | None:
    """
    True → endpoint rejected unauthenticated request (401/403).
    False → reachable without key (or auth already present and ok).
    None → probe inconclusive (network / other HTTP).
    """
    if settings.api == "anthropic":
        return settings.api_key is None

    url = f"{settings.endpoint}/models"
    headers: dict[str, str] = {}
    if settings.api_key:
        name = (settings.api_header_name or "").strip()
        if not name or name.lower() == "authorization":
            headers["Authorization"] = f"Bearer {settings.api_key}"
        else:
            headers[name] = settings.api_key

    try:
        with httpx.Client(timeout=15.0) as client:
            resp = client.get(url, headers=headers)
    except httpx.HTTPError:
        return None

    if resp.status_code in (401, 403):
        return True
    if resp.status_code < 400:
        return False
    return None


def _try_headers(settings: Settings, api_key: str) -> list[str | None]:
    """Candidate header names; None means Authorization: Bearer."""
    ordered: list[str | None] = []
    if settings.api_header_name:
        ordered.append(settings.api_header_name.strip() or None)
    for candidate in (None, "X-API-KEY", "x-api-key"):
        if candidate not in ordered:
            ordered.append(candidate)
    return ordered


def _header_works(settings: Settings, api_key: str, header_name: str | None) -> bool:
    trial = replace(settings, api_key=api_key, api_header_name=header_name)
    need = probe_needs_auth(trial)
    return need is False


def apply_api_key(
    settings: Settings,
    api_key: str,
    *,
    preferred_header: str | None = None,
) -> Settings:
    """Validate key against /models, pick header, cache credentials."""
    api_key = api_key.strip()
    if not api_key:
        raise RuntimeError("No API key entered.")

    trial = settings
    if preferred_header is not None:
        # Explicit empty string → Bearer
        hdr = preferred_header.strip() or None
        if preferred_header.strip().lower() == "authorization":
            hdr = None
        ordered = [hdr] + [h for h in _try_headers(settings, api_key) if h != hdr]
    else:
        ordered = _try_headers(settings, api_key)

    chosen: str | None = None
    for header in ordered:
        if _header_works(trial, api_key, header):
            chosen = header
            break

    if chosen is None:
        chosen = (
            None
            if (preferred_header or "").strip().lower() == "authorization"
            else (preferred_header.strip() if preferred_header else "X-API-KEY")
        )

    save_cached_auth(settings.endpoint, api_key, chosen)
    return replace(settings, api_key=api_key, api_header_name=chosen)


def prompt_and_store_auth(settings: Settings) -> Settings:
    """Ask for API key on TTY, detect header, cache under ~/.config/ncc-assistant/."""
    if not sys.stdin.isatty():
        raise RuntimeError(
            "LLM endpoint requires authentication but no API key is available "
            "and stdin is not a TTY. Set apiKeyFile, export NCC_ASSISTANT_API_KEY, "
            f"or run `ncc ai` interactively once to cache credentials for {settings.endpoint}."
        )

    host = urlparse(settings.endpoint).netloc or settings.endpoint
    print(f"Auth required for {host}.", file=sys.stderr)
    print(
        "Key is stored only in ~/.config/ncc-assistant/credentials.json (0600), "
        "not in systemConfig.",
        file=sys.stderr,
    )
    api_key = getpass("API key: ").strip()
    updated = apply_api_key(settings, api_key)
    label = (
        "Authorization: Bearer"
        if not updated.api_header_name
        else updated.api_header_name
    )
    print(f"Auth OK ({label}).", file=sys.stderr)
    print(f"Saved credentials → {credentials_path()}", file=sys.stderr)
    return updated


def with_cached_credentials(settings: Settings) -> Settings:
    """Fill api_key / header from local cache when not already set."""
    if settings.api_key:
        return settings
    key, header = load_cached_auth(settings.endpoint)
    if not key:
        return settings
    return replace(
        settings,
        api_key=key,
        api_header_name=settings.api_header_name or header,
    )


def ensure_auth(settings: Settings, *, interactive: bool = True) -> Settings:
    """
    Resolve credentials for chat:
    1. env / apiKeyFile (already in settings)
    2. ~/.config/ncc-assistant cache
    3. If endpoint needs auth → interactive prompt (chat only)
    """
    settings = with_cached_credentials(settings)
    if settings.api_key:
        return settings

    need = probe_needs_auth(settings)
    if need is False:
        return settings
    if need is None and settings.api != "anthropic":
        # Inconclusive — don't force a prompt; let the first request fail loudly.
        return settings
    if not interactive:
        return settings
    return prompt_and_store_auth(settings)


def refresh_auth_on_unauthorized(
    settings: Settings, err: BaseException, *, interactive: bool = True
) -> Settings | None:
    """If error looks like 401/403, re-prompt and return updated settings."""
    text = str(err).lower()
    if "401" not in text and "403" not in text and "unauthorized" not in text:
        return None
    if not interactive:
        return None
    print("Authentication rejected — enter a new API key.", file=sys.stderr)
    return prompt_and_store_auth(replace(settings, api_key=None))
