#!/usr/bin/env python3
"""GUI soak tests — stability under repeated reload / navigation.

Stages (all optional; require NCC_GUI_SOAK=1):

  A — each domain page ``reload()`` N times (no crash)
  B — ``NccShell`` roundtrip across catalog domains (force remount)
  C — memory delta after B (optional limit via NCC_GUI_SOAK_MEMORY_MB)

  python3 tests/gui/test_gui_soak.py
  NCC_GUI_SOAK=1 NCC_GUI_SOAK_ROUNDS=20 python3 tests/gui/test_gui_soak.py
  NCC_GUI_SOAK=1 NCC_GUI_SOAK_MEMORY_MB=80 python3 tests/gui/test_gui_soak.py
"""

from __future__ import annotations

import gc
import os
import tracemalloc
import unittest
from unittest.mock import patch

from gui_soak_support import (
    GuiSoakBase,
    discover_page_files,
    load_page_module,
    memory_limit_mb,
    minimal_catalog_json,
    patch_heavy_page_probes,
    soak_rounds,
    stop_probe_patches,
)

REPO = __import__("pathlib").Path(__file__).resolve().parents[2]


class GuiSoakStageA(GuiSoakBase):
  """Domain page reload roundtrip."""

  def test_domain_pages_reload_roundtrip(self) -> None:
    from PySide6.QtWidgets import QWidget

    patch_heavy_page_probes(self)
    rounds = soak_rounds()
    pages = discover_page_files()
    self.assertTrue(pages)
    loaded = 0
    for path in pages:
      rel = path.relative_to(REPO)
      try:
        mod = load_page_module(path)
      except Exception as exc:
        print(f"skip {rel}: load failed ({exc})")
        continue
      create = getattr(mod, "create_page", None)
      if not callable(create):
        print(f"skip {rel}: missing create_page()")
        continue
      try:
        widget = create()
      except Exception as exc:
        print(f"skip {rel}: create failed ({exc})")
        continue
      if not isinstance(widget, QWidget):
        print(f"skip {rel}: not a QWidget")
        continue
      loaded += 1
      self._noop_probe(widget, "_start_fs_status_probe")
      self._noop_probe(widget, "_start_store_status_probe")
      reload_fn = getattr(widget, "reload", None)
      if callable(reload_fn):
        for _ in range(rounds):
          reload_fn()
      widget.deleteLater()
    self.assertGreater(loaded, 0, "expected at least one soakable domain page")
    stop_probe_patches(self)


class GuiSoakStageB(GuiSoakBase):
  """Shell navigation soak — mount every domain repeatedly."""

  def test_shell_domain_roundtrip(self) -> None:
    os.environ["NCC_GUI_CATALOG"] = minimal_catalog_json()
    patch_heavy_page_probes(self)

    from ncc_gui.catalog import DomainInfo, load_domains
    from ncc_gui.pages.generic import GenericDomainPage
    from ncc_gui.shell import NccShell

    domains = load_domains()
    self.assertGreaterEqual(len(domains), 3)

    page_map: dict[str, object] = {}
    for path in discover_page_files():
      parts = path.parts
      try:
        idx = parts.index("ui")
        domain_id = parts[idx - 1].replace("_", "-")
      except ValueError:
        continue
      try:
        mod = load_page_module(path)
        create = getattr(mod, "create_page", None)
        if callable(create):
          page_map[domain_id] = create
      except Exception:
        continue

    def build_page(info: DomainInfo):
      factory = page_map.get(info.id)
      if factory is not None:
        page = factory()
        self._noop_probe(page, "_start_fs_status_probe")
        self._noop_probe(page, "_start_store_status_probe")
        return page
      return GenericDomainPage(info)

    with patch(
      "ncc_gui.target_session.session_controller",
    ) as mock_ctrl:
      from ncc_gui.target_session import TargetSession

      mock_ctrl.return_value.session.return_value = TargetSession(
          state="idle",
          candidate=None,
          connected=None,
          probe=None,
      )
      shell = NccShell(domains, build_page, title="Soak")
      rounds = soak_rounds()
      domain_ids = [d.id for d in domains if d.enabled]
      for _ in range(rounds):
        for did in domain_ids:
          shell.select_domain(did)
          shell._mount_domain(did, force=True)
      shell.close()
    stop_probe_patches(self)


class GuiSoakStageC(GuiSoakBase):
  """Memory soak after shell roundtrip (tracemalloc delta)."""

  def test_shell_memory_delta(self) -> None:
    limit = memory_limit_mb()
    if limit is None:
      self.skipTest("set NCC_GUI_SOAK_MEMORY_MB to enforce memory ceiling")

    os.environ["NCC_GUI_CATALOG"] = minimal_catalog_json()
    patch_heavy_page_probes(self)

    from ncc_gui.catalog import DomainInfo, load_domains
    from ncc_gui.pages.generic import GenericDomainPage
    from ncc_gui.shell import NccShell
    from ncc_gui.target_session import TargetSession

    domains = load_domains()

    def build_page(info: DomainInfo):
      return GenericDomainPage(info)

    tracemalloc.start()
    snap_before = tracemalloc.take_snapshot()

    with patch("ncc_gui.target_session.session_controller") as mock_ctrl:
      mock_ctrl.return_value.session.return_value = TargetSession(
          state="idle",
          candidate=None,
          connected=None,
          probe=None,
      )
      shell = NccShell(domains, build_page, title="Soak mem")
      rounds = max(5, soak_rounds() // 2)
      domain_ids = [d.id for d in domains if d.enabled]
      for _ in range(rounds):
        for did in domain_ids:
          shell.select_domain(did)
          shell._mount_domain(did, force=True)
      shell.close()

    gc.collect()
    snap_after = tracemalloc.take_snapshot()
    tracemalloc.stop()

    before = sum(s.size for s in snap_before.statistics("lineno"))
    after = sum(s.size for s in snap_after.statistics("lineno"))
    delta_mb = max(0, after - before) / (1024 * 1024)
    self.assertLess(
      delta_mb,
      limit,
      f"memory grew {delta_mb:.1f} MB (limit {limit} MB)",
    )
    stop_probe_patches(self)


class GuiSoakStageBMockedNcc(GuiSoakBase):
  """Stacks/System async paths with mocked ``run_ncc`` (no real subprocess)."""

  def test_mocked_ncc_reload_on_heavy_pages(self) -> None:
    import subprocess

    patch_heavy_page_probes(self)

    def fake_run_ncc(*args, **kwargs):
      return subprocess.CompletedProcess(args=list(args), returncode=0, stdout="{}", stderr="")

    with patch("ncc_gui.remote.run_ncc", side_effect=fake_run_ncc):
      rounds = max(5, soak_rounds() // 2)
      targets = []
      for path in discover_page_files():
        if path.parts[-3] not in ("system-manager", "stack-manager", "install-wizard"):
          continue
        try:
          mod = load_page_module(path)
          create = getattr(mod, "create_page", None)
          if not callable(create):
            continue
          page = create()
          self._noop_probe(page, "_start_fs_status_probe")
          self._noop_probe(page, "_start_store_status_probe")
          reload_fn = getattr(page, "reload", None)
          if callable(reload_fn):
            for _ in range(rounds):
              reload_fn()
          targets.append(page)
        except Exception as exc:
          self.fail(f"{path}: {exc}")
      for page in targets:
        page.deleteLater()
    stop_probe_patches(self)


if __name__ == "__main__":
  raise SystemExit(unittest.main(verbosity=2))
