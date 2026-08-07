"""Resolve a domain page: module ui/gui via ncc_domain_page, else generic.

Discovery order:
  1. ncc_domain_page.<id>  — registered by modules (registerGuiPage)
  2. GenericDomainPage(info) — zero custom GUI code
"""

from __future__ import annotations

import importlib
from typing import Callable

from PySide6.QtWidgets import QWidget

from ncc_gui.catalog import DomainInfo
from ncc_gui.pages.generic import GenericDomainPage


def _try_page(mod) -> QWidget | None:
    create: Callable[..., QWidget] | None = getattr(mod, "create_page", None)
    if callable(create):
        return create()
    page_cls = getattr(mod, "Page", None)
    if page_cls is not None:
        return page_cls()
    return None


def create_page_for(info: DomainInfo) -> QWidget:
    sid = info.id.replace("-", "_")
    try:
        mod = importlib.import_module(f"ncc_domain_page.{sid}")
    except ImportError:
        return GenericDomainPage(info)

    page = _try_page(mod)
    return page if page is not None else GenericDomainPage(info)
