"""Discover settings tabs: core + ncc_domain_page.<id>.settings."""

from __future__ import annotations

import importlib
import pkgutil
from typing import Iterable

from ncc_gui.catalog import DomainInfo, load_domains
from ncc_gui.settings.core_tabs import core_settings_tabs
from ncc_gui.settings.protocol import SettingsTabSpec


def _enabled_domain_ids(domains: list[DomainInfo] | None = None) -> set[str]:
    doms = domains if domains is not None else load_domains()
    return {d.id for d in doms if d.enabled}


def _domain_allowed(spec: SettingsTabSpec, enabled: set[str]) -> bool:
    if not spec.requires_domains:
        return True
    return all(d in enabled for d in spec.requires_domains)


def _load_module_tabs() -> list[SettingsTabSpec]:
    out: list[SettingsTabSpec] = []
    try:
        import ncc_domain_page as pkg
    except ImportError:
        return out

    paths = getattr(pkg, "__path__", None)
    if not paths:
        return out

    for info in pkgutil.iter_modules(paths):
        if info.name.startswith("_"):
            continue
        try:
            mod = importlib.import_module(f"ncc_domain_page.{info.name}.settings")
        except ImportError:
            continue
        getter = getattr(mod, "get_settings_tab", None)
        if not callable(getter):
            continue
        try:
            spec = getter()
        except Exception:
            continue
        if isinstance(spec, SettingsTabSpec):
            out.append(spec)
        elif isinstance(spec, list):
            out.extend(s for s in spec if isinstance(s, SettingsTabSpec))
    return out


def discover_settings_tabs(
    *,
    domains: list[DomainInfo] | None = None,
) -> list[SettingsTabSpec]:
    """Core tabs + module ``settings.py`` contributions, filtered by catalog."""
    enabled = _enabled_domain_ids(domains)
    specs: list[SettingsTabSpec] = []
    specs.extend(core_settings_tabs(enabled_domains=enabled))
    specs.extend(_load_module_tabs())

    visible = [s for s in specs if _domain_allowed(s, enabled)]
    # Dedupe by id (first wins — core before modules if same id)
    seen: set[str] = set()
    unique: list[SettingsTabSpec] = []
    for s in sorted(visible, key=lambda t: (t.order, t.title.lower())):
        if s.id in seen:
            continue
        seen.add(s.id)
        unique.append(s)
    return unique


def iter_settings_tabs() -> Iterable[SettingsTabSpec]:
    return discover_settings_tabs()
