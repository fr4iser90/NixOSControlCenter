"""User-managed LLM providers under ~/.config/ncc-assistant/providers.json."""

from __future__ import annotations

import json
import os
import re
import uuid
from dataclasses import dataclass, field
from typing import Any
from urllib.parse import urlparse

from .config import normalize_endpoint, resolve_api
from .paths import providers_file


def normalize_auth_header(name: str | None) -> str | None:
    """None → Authorization: Bearer. Other values are raw header names (e.g. X-API-KEY)."""
    if name is None:
        return None
    n = name.strip()
    if not n:
        return None
    low = n.lower()
    if low in ("authorization", "bearer", "authorization: bearer", "auto"):
        return None
    return n


def _parse_extra_headers(raw: Any) -> dict[str, str]:
    out: dict[str, str] = {}
    if isinstance(raw, dict):
        for k, v in raw.items():
            key = str(k).strip()
            if key and v is not None and str(v).strip():
                out[key] = str(v).strip()
    elif isinstance(raw, list):
        for row in raw:
            if not isinstance(row, dict):
                continue
            key = str(row.get("name") or row.get("key") or "").strip()
            val = str(row.get("value") or "").strip()
            if key and val:
                out[key] = val
    return out


@dataclass
class Provider:
    id: str
    name: str
    api: str  # openai-compatible | anthropic
    endpoint: str
    # None → Bearer Authorization; else custom header name for the API key
    auth_header: str | None = None
    # Extra request headers (org ids, x-ai-*, etc.) — not the primary API key
    extra_headers: dict[str, str] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        d: dict[str, Any] = {
            "id": self.id,
            "name": self.name,
            "api": self.api,
            "endpoint": self.endpoint,
        }
        if self.auth_header:
            d["auth_header"] = self.auth_header
        if self.extra_headers:
            d["extra_headers"] = dict(self.extra_headers)
        return d

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> Provider | None:
        pid = str(raw.get("id") or "").strip()
        name = str(raw.get("name") or "").strip()
        endpoint = str(raw.get("endpoint") or "").strip()
        if not pid or not name or not endpoint:
            return None
        api = resolve_api(str(raw.get("api") or "openai-compatible"), None)
        auth = normalize_auth_header(
            str(raw.get("auth_header") or raw.get("api_header_name") or "") or None
        )
        return cls(
            id=pid,
            name=name,
            api=api,
            endpoint=normalize_endpoint(endpoint),
            auth_header=auth,
            extra_headers=_parse_extra_headers(raw.get("extra_headers")),
        )


def _slug_from_endpoint(endpoint: str) -> str:
    host = urlparse(endpoint).netloc or "local"
    host = re.sub(r"[^a-zA-Z0-9.-]+", "-", host).strip("-").lower() or "local"
    return host[:48]


def _nix_seed_provider() -> Provider:
    from .config import Settings

    s = Settings.from_env(client_mode="chat")
    host = urlparse(s.endpoint).netloc or "default"
    return Provider(
        id=_slug_from_endpoint(s.endpoint) or "default",
        name=host,
        api=s.api,
        endpoint=s.endpoint,
        auth_header=normalize_auth_header(s.api_header_name),
        extra_headers=dict(s.extra_headers),
    )


def load_providers() -> list[Provider]:
    path = providers_file()
    if not path.is_file():
        seed = _nix_seed_provider()
        save_providers([seed])
        return [seed]
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        seed = _nix_seed_provider()
        save_providers([seed])
        return [seed]
    items = data.get("providers") if isinstance(data, dict) else data
    if not isinstance(items, list):
        seed = _nix_seed_provider()
        save_providers([seed])
        return [seed]
    out: list[Provider] = []
    for raw in items:
        if isinstance(raw, dict):
            p = Provider.from_dict(raw)
            if p:
                out.append(p)
    if not out:
        seed = _nix_seed_provider()
        save_providers([seed])
        return [seed]
    return out


def save_providers(providers: list[Provider]) -> None:
    path = providers_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {"providers": [p.to_dict() for p in providers]}
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def get_provider(provider_id: str) -> Provider | None:
    for p in load_providers():
        if p.id == provider_id:
            return p
    return None


def find_provider_by_endpoint(endpoint: str) -> Provider | None:
    want = normalize_endpoint(endpoint)
    for p in load_providers():
        if p.endpoint.rstrip("/") == want.rstrip("/"):
            return p
    return None


def add_provider(
    *,
    name: str,
    endpoint: str,
    api: str = "openai-compatible",
    provider_id: str | None = None,
    auth_header: str | None = None,
    extra_headers: dict[str, str] | None = None,
) -> Provider:
    providers = load_providers()
    ep = normalize_endpoint(endpoint)
    extras = dict(extra_headers or {})
    auth = normalize_auth_header(auth_header)
    existing = find_provider_by_endpoint(ep)
    if existing:
        existing.name = name.strip() or existing.name
        existing.api = resolve_api(api, None)
        existing.auth_header = auth
        existing.extra_headers = extras
        save_providers(providers)
        return existing
    pid = (provider_id or "").strip() or _slug_from_endpoint(ep)
    ids = {p.id for p in providers}
    base = pid
    n = 2
    while pid in ids:
        pid = f"{base}-{n}"
        n += 1
    prov = Provider(
        id=pid,
        name=name.strip() or urlparse(ep).netloc or pid,
        api=resolve_api(api, None),
        endpoint=ep,
        auth_header=auth,
        extra_headers=extras,
    )
    providers.append(prov)
    save_providers(providers)
    return prov


def update_provider(provider: Provider) -> Provider:
    """Replace an existing provider by id (or append if unknown)."""
    providers = load_providers()
    provider.auth_header = normalize_auth_header(provider.auth_header)
    provider.endpoint = normalize_endpoint(provider.endpoint)
    provider.api = resolve_api(provider.api, None)
    for i, p in enumerate(providers):
        if p.id == provider.id:
            providers[i] = provider
            save_providers(providers)
            return provider
    providers.append(provider)
    save_providers(providers)
    return provider


def remove_provider(provider_id: str) -> bool:
    providers = load_providers()
    if len(providers) <= 1:
        return False
    new = [p for p in providers if p.id != provider_id]
    if len(new) == len(providers):
        return False
    save_providers(new)
    return True


def ensure_seeded() -> list[Provider]:
    """Load providers, seeding from Nix env if missing."""
    return load_providers()


def new_provider_id() -> str:
    return uuid.uuid4().hex[:8]


def apply_provider_settings(settings: Any, provider: Provider) -> Any:
    """Return Settings with endpoint/api/headers from provider (key cleared for re-cache)."""
    from dataclasses import replace

    from .config import Settings

    if not isinstance(settings, Settings):
        raise TypeError("settings must be Settings")
    return replace(
        settings,
        endpoint=provider.endpoint,
        api=provider.api,
        api_key=None,
        api_header_name=provider.auth_header,
        extra_headers=tuple(sorted(provider.extra_headers.items())),
    )
