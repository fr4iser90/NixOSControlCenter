#!/usr/bin/env python3
"""Hyprland page must require NCC_HYPRLAND_CATALOG (no live nix eval)."""

from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PAGE = REPO / "nixos/core/base/hyprland/ui/gui/page.py"


def _load_page_module():
    spec = importlib.util.spec_from_file_location("hyprland_page", PAGE)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    # Minimal stubs if imports pull Qt — page imports PySide6 at top.
    spec.loader.exec_module(mod)
    return mod


class HyprlandCatalogHotpathTests(unittest.TestCase):
    def test_source_has_no_live_nix_eval(self) -> None:
        text = PAGE.read_text(encoding="utf-8")
        # Ban call sites / builders (docstrings may mention the policy in words).
        self.assertNotIn('["nix-instantiate"', text)
        self.assertNotIn("'nix-instantiate'", text)
        self.assertNotIn("import <nixpkgs>", text)
        self.assertNotIn("mk-catalog-json", text)

    @unittest.skipUnless(
        importlib.util.find_spec("PySide6") is not None,
        "PySide6 required to import page module",
    )
    def test_load_catalog_requires_env(self) -> None:
        os.environ.pop("NCC_HYPRLAND_CATALOG", None)
        mod = _load_page_module()
        with self.assertRaises(RuntimeError) as ctx:
            mod.load_catalog()
        self.assertIn("NCC_HYPRLAND_CATALOG", str(ctx.exception))

    @unittest.skipUnless(
        importlib.util.find_spec("PySide6") is not None,
        "PySide6 required to import page module",
    )
    def test_load_catalog_reads_json(self) -> None:
        payload = {"rices": [], "categories": [], "storeRices": [], "galleryRices": []}
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh:
            json.dump(payload, fh)
            path = fh.name
        try:
            os.environ["NCC_HYPRLAND_CATALOG"] = path
            mod = _load_page_module()
            data = mod.load_catalog()
            self.assertEqual(data["rices"], [])
        finally:
            os.environ.pop("NCC_HYPRLAND_CATALOG", None)
            Path(path).unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(unittest.main(verbosity=2))
