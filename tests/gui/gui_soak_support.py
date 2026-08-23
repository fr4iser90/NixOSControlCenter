"""Shared helpers for GUI soak tests (A/B/C)."""

from __future__ import annotations

import importlib.util
import json
import os
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
NIXOS = REPO / "nixos"
GUI_PY = NIXOS / "core/management/gui-engine/python"
ASSISTANT_PY = NIXOS / "modules/specialized/ncc-assistant/python"


def soak_enabled() -> bool:
    return os.environ.get("NCC_GUI_SOAK", "").strip() in ("1", "true", "yes")


def soak_rounds(default: int = 20) -> int:
    raw = os.environ.get("NCC_GUI_SOAK_ROUNDS", "").strip()
    if raw.isdigit():
        return max(1, int(raw))
    return default


def memory_limit_mb() -> int | None:
    raw = os.environ.get("NCC_GUI_SOAK_MEMORY_MB", "").strip()
    if raw.isdigit():
        return int(raw)
    return None


def ensure_gui_paths() -> None:
    for p in (GUI_PY, ASSISTANT_PY):
        ps = str(p)
        if ps not in sys.path:
            sys.path.insert(0, ps)
    os.environ.setdefault(
        "NCC_HOST_POLICY", '{"dangerousIgnore":false,"autoBuild":false}'
    )


def discover_page_files() -> list[Path]:
    return sorted(NIXOS.rglob("ui/gui/page.py"))


def load_page_module(path: Path):
    rel = path.relative_to(NIXOS)
    mod_name = "ncc_page_" + "_".join(rel.parts).replace(".", "_").replace("-", "_")
    spec = importlib.util.spec_from_file_location(mod_name, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def minimal_catalog_json() -> str:
    """Catalog ids aligned with common registerGuiDomain names for shell soak."""
    domains = [
        ("system", "System", "core"),
        ("install", "Install", "core"),
        ("packages", "Packages", "core"),
        ("network", "Network", "core"),
        ("desktop", "Desktop", "core"),
        ("users", "Users", "core"),
        ("hardware", "Hardware", "core"),
        ("modules", "Modules", "core"),
        ("stacks", "Stacks", "features"),
        ("ssh", "SSH", "features"),
        ("vms", "VMs", "features"),
    ]
    payload = [
        {
            "id": did,
            "label": label,
            "description": f"{label} soak",
            "enabled": True,
            "group": group,
            "actions": [],
        }
        for did, label, group in domains
    ]
    return json.dumps(payload)


def patch_heavy_page_probes(test_case: unittest.TestCase) -> None:
    """Stop QProcess/remote probes during soak (System, Install, …)."""
    from unittest.mock import patch

    patches = [
        patch(
            "ncc_gui.system_fs_status.build_fs_status_argv",
            return_value=["echo", "hostname=soak"],
        ),
    ]
    for p in patches:
        test_case._probe_patchers = getattr(test_case, "_probe_patchers", [])
        test_case._probe_patchers.append(p)
        p.start()

    def _noop_probe(page, method_name: str) -> None:
        if hasattr(page, method_name):
            setattr(page, method_name, lambda: None)

    test_case._noop_probe = _noop_probe


def stop_probe_patches(test_case: unittest.TestCase) -> None:
    for p in getattr(test_case, "_probe_patchers", []):
        p.stop()


class GuiSoakBase(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not soak_enabled():
            raise unittest.SkipTest("set NCC_GUI_SOAK=1 to run GUI soak tests")
        ensure_gui_paths()

    def setUp(self) -> None:
        try:
            from PySide6.QtWidgets import QApplication
        except ImportError:
            self.skipTest("PySide6 not installed")
        self._app = QApplication.instance() or QApplication([])  # noqa: F841
