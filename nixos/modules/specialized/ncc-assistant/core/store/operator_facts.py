"""Operator facts (country / locale / notes) for GitHub Agent legal-gap elevation.

Callers: ``core.workflows.github_agent.run_github_agent``, CLI
``ncc ai github-agent``, Companion PANEL_GITHUB facts action,
``tests/ncc-assistant/test_github_agent_v1.py``.

No duplicate of preferences — country/locale are operator identity, not UI chrome.
Schema: ``{version, country, locale, notes}`` under ``operator-facts.json`` (0600).

User intent: DE/AT/CH elevate missing impressum/privacy to p0 on the GitHub Agent board.
"""

from __future__ import annotations

import json
import os
from typing import Any

from core.store.paths import operator_facts_file

SCHEMA_VERSION = 1
DEFAULT_COUNTRY = "DE"
DEFAULT_LOCALE = "de-DE"
DACH_COUNTRIES = frozenset({"DE", "AT", "CH"})


def _defaults() -> dict[str, Any]:
    return {
        "version": SCHEMA_VERSION,
        "country": DEFAULT_COUNTRY,
        "locale": DEFAULT_LOCALE,
        "notes": "",
    }


def load_operator_facts() -> dict[str, Any]:
    path = operator_facts_file()
    base = _defaults()
    if not path.is_file():
        return base
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return base
    if not isinstance(data, dict):
        return base
    country = str(data.get("country") or DEFAULT_COUNTRY).strip().upper() or DEFAULT_COUNTRY
    locale = str(data.get("locale") or DEFAULT_LOCALE).strip() or DEFAULT_LOCALE
    notes = str(data.get("notes") or "")
    return {
        "version": int(data.get("version") or SCHEMA_VERSION),
        "country": country,
        "locale": locale,
        "notes": notes,
    }


def save_operator_facts(data: dict[str, Any]) -> dict[str, Any]:
    path = operator_facts_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    current = load_operator_facts()
    if "country" in data and data["country"] is not None:
        current["country"] = str(data["country"]).strip().upper() or DEFAULT_COUNTRY
    if "locale" in data and data["locale"] is not None:
        current["locale"] = str(data["locale"]).strip() or DEFAULT_LOCALE
    if "notes" in data and data["notes"] is not None:
        current["notes"] = str(data["notes"])
    current["version"] = SCHEMA_VERSION
    path.write_text(
        json.dumps(current, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass
    return current


def get_operator_country() -> str:
    return str(load_operator_facts().get("country") or DEFAULT_COUNTRY)


def get_operator_locale() -> str:
    return str(load_operator_facts().get("locale") or DEFAULT_LOCALE)


def get_operator_notes() -> str:
    return str(load_operator_facts().get("notes") or "")


def set_operator_country(country: str) -> dict[str, Any]:
    return save_operator_facts({"country": country})


def set_operator_locale(locale: str) -> dict[str, Any]:
    return save_operator_facts({"locale": locale})


def set_operator_notes(notes: str) -> dict[str, Any]:
    return save_operator_facts({"notes": notes})


def is_dach_country(country: str | None = None) -> bool:
    c = (country or get_operator_country()).strip().upper()
    return c in DACH_COUNTRIES
