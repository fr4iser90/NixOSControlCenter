"""Resolve a domain page: optional ncc_gui.pages.<id>, else generic."""

from __future__ import annotations

import importlib
from typing import Callable

from PySide6.QtWidgets import QWidget

from ncc_gui.catalog import DomainInfo
from ncc_gui.pages.generic import GenericDomainPage


def create_page_for(info: DomainInfo) -> QWidget:
    """
    Discovery order:
      1. ncc_gui.pages.<id>.create_page()
      2. ncc_gui.pages.<id>.Page
      3. GenericDomainPage(info)  — works for any new module with zero GUI code
    """
    mod_name = f"ncc_gui.pages.{info.id.replace('-', '_')}"
    try:
        mod = importlib.import_module(mod_name)
    except ImportError:
        return GenericDomainPage(info)

    create: Callable[..., QWidget] | None = getattr(mod, "create_page", None)
    if callable(create):
        return create()

    page_cls = getattr(mod, "Page", None)
    if page_cls is not None:
        return page_cls()

    return GenericDomainPage(info)
