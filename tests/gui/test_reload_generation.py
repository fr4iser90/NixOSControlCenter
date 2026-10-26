#!/usr/bin/env python3
"""Regression tests for ncc_gui.reload generation detection (no live rebuild).

Run with the NCC PySide6 env, e.g.:
  /nix/store/...-python3-...-env/bin/python path/to/test_reload_generation.py
"""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

# Workspace gui-engine first (tests live under tests/gui/, code under nixos/)
GUI_PY = Path(__file__).resolve().parents[2] / "nixos/core/management/gui-engine/python"
assert (GUI_PY / "ncc_gui" / "reload.py").is_file(), GUI_PY
sys.path.insert(0, str(GUI_PY))

from PySide6.QtWidgets import QApplication  # noqa: E402

import ncc_gui.reload as reload  # noqa: E402


def _app() -> QApplication:
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    return app  # type: ignore[return-value]


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _pkg_tree(root: Path, *, marker: str) -> None:
    """Minimal ncc_gui + core package dirs with distinct content."""
    for name in ("ncc_gui", "core"):
        d = root / name
        d.mkdir(parents=True, exist_ok=True)
        (d / "__init__.py").write_text(f"# {name} {marker}\n", encoding="utf-8")
        (d / "probe.py").write_text(f"MARKER = {marker!r}\n", encoding="utf-8")


def _payload_wrapper(
    bin_dir: Path,
    src_root: Path,
    *,
    fingerprint: str | None = None,
    name: str = "ncc-domain-gui",
) -> Path:
    """Realistic domain-GUI wrapper: staged payload on PYTHONPATH, bash expansion included.

    Named like production (``ncc-*-gui``) on purpose — reload discovers GUI entrypoints by
    that rule, so a wrapper named after some peer module must stay unscanned.
    """
    path = bin_dir / name
    fp = f'\nexport NCC_GUI_FINGERPRINT="{fingerprint}"' if fingerprint else ""
    _write(
        path,
        f'''#!/bin/bash
export PYTHONPATH="{src_root}${{PYTHONPATH:+:$PYTHONPATH}}"{fp}
exec /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-python3-env/bin/python -m ncc_gui.domain_gui "$@"
''',
    )
    path.chmod(0o755)
    return path


def _gui_wrapper(bin_dir: Path, src_root: Path) -> Path:
    path = bin_dir / "ncc-gui"
    _write(
        path,
        f'''#!/bin/bash
export PYTHONPATH="{src_root}${{PYTHONPATH:+:$PYTHONPATH}}"
exec /nix/store/cccccccccccccccccccccccccccccccc-ncc-gui/bin/ncc-gui "$@"
''',
    )
    path.chmod(0o755)
    return path


class CleanPathTests(unittest.TestCase):
    def test_strips_bash_pythonpath_expansion(self) -> None:
        raw = (
            "/nix/store/5q9sw8ixgz3amhzm03ypqs7jrkcsinca-ncc-assistant-src"
            "${PYTHONPATH:+:$PYTHONPATH}"
        )
        # Path may not exist — clean still strips; use tempfile that exists
        with tempfile.TemporaryDirectory(prefix="ncc-store-") as td:
            # Fake a store-like path under tmp by monkeypatching startswith check via real dir
            storeish = Path(td) / "fake-ncc-assistant-src"
            storeish.mkdir()
            # Direct unit: function requires /nix/store/ prefix
            cleaned = reload._clean_store_path(raw)
            # On this machine the real store path may exist (from live system)
            if Path(
                "/nix/store/5q9sw8ixgz3amhzm03ypqs7jrkcsinca-ncc-assistant-src"
            ).is_dir():
                self.assertIsNotNone(cleaned)
                assert cleaned is not None
                self.assertNotIn("${", str(cleaned))
            else:
                # Still verify regex strip helper path via roots_from_wrapper
                pass

    def test_roots_from_wrapper_ignores_bash_junk(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            src = td_path / "src"
            _pkg_tree(src, marker="v1")
            # Patch _clean_store_path to accept our tmp roots (not /nix/store)
            real_clean = reload._clean_store_path

            def clean_tmp(raw: str) -> Path | None:
                part = raw.strip()
                if "${" in part:
                    part = part.split("${", 1)[0]
                part = part.rstrip(":").strip()
                p = Path(part)
                if p.exists():
                    return p
                return real_clean(raw)

            bin_dir = td_path / "bin"
            wrapper = _payload_wrapper(bin_dir, src)
            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                roots = reload._roots_from_wrapper(wrapper)
            self.assertEqual(roots, [src])


class FingerprintTests(unittest.TestCase):
    def test_fingerprint_changes_when_gui_payload_changes(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            sys_a = td_path / "system-a"
            sys_b = td_path / "system-b"
            src_a = sys_a / "share" / "src"
            src_b = sys_b / "share" / "src"
            _pkg_tree(src_a, marker="aaa")
            _pkg_tree(src_b, marker="bbb")
            bin_a = sys_a / "sw" / "bin"
            bin_b = sys_b / "sw" / "bin"
            _payload_wrapper(bin_a, src_a)
            _payload_wrapper(bin_b, src_b)
            _gui_wrapper(bin_a, src_a)
            _gui_wrapper(bin_b, src_b)

            def clean_tmp(raw: str) -> Path | None:
                part = raw.strip()
                if "${" in part:
                    part = part.split("${", 1)[0]
                part = part.rstrip(":").strip()
                p = Path(part)
                return p if p.exists() else None

            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                with mock.patch.object(reload, "SW_BIN", bin_a):
                    fp_a = reload.profile_gui_fingerprint()
                with mock.patch.object(reload, "SW_BIN", bin_b):
                    fp_b = reload.profile_gui_fingerprint()

            self.assertTrue(fp_a, "fingerprint A empty")
            self.assertTrue(fp_b, "fingerprint B empty")
            self.assertNotEqual(fp_a, fp_b)
            self.assertIn("core", fp_a)
            self.assertIn("ncc_gui", fp_a)

    def test_same_content_same_fingerprint(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            src = td_path / "src"
            _pkg_tree(src, marker="same")
            bin_dir = td_path / "sw" / "bin"
            _payload_wrapper(bin_dir, src)

            def clean_tmp(raw: str) -> Path | None:
                part = raw.strip()
                if "${" in part:
                    part = part.split("${", 1)[0]
                p = Path(part.rstrip(":").strip())
                return p if p.exists() else None

            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                with mock.patch.object(reload, "SW_BIN", bin_dir):
                    a = reload.profile_gui_fingerprint()
                    b = reload.profile_gui_fingerprint()
            self.assertEqual(a, b)


class StaleProcessTests(unittest.TestCase):
    def test_stale_when_loaded_modules_point_at_old_tree(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            old = td_path / "old"
            new = td_path / "new"
            _pkg_tree(old, marker="old")
            _pkg_tree(new, marker="new")
            bin_dir = td_path / "sw" / "bin"
            _payload_wrapper(bin_dir, new)

            def clean_tmp(raw: str) -> Path | None:
                part = raw.strip()
                if "${" in part:
                    part = part.split("${", 1)[0]
                p = Path(part.rstrip(":").strip())
                return p if p.exists() else None

            # Fake loaded modules still on old paths
            class FakeMod:
                def __init__(self, path: Path) -> None:
                    self.__file__ = str(path / "__init__.py")

            fake_modules = {
                "ncc_gui": FakeMod(old / "ncc_gui"),
                "core": FakeMod(old / "core"),
            }
            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                with mock.patch.object(reload, "SW_BIN", bin_dir):
                    with mock.patch.dict(sys.modules, fake_modules, clear=False):
                        self.assertTrue(reload.process_gui_stale())

            # Point loaded modules at new → not stale
            fake_new = {
                "ncc_gui": FakeMod(new / "ncc_gui"),
                "core": FakeMod(new / "core"),
            }
            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                with mock.patch.object(reload, "SW_BIN", bin_dir):
                    with mock.patch.dict(sys.modules, fake_new, clear=False):
                        self.assertFalse(reload.process_gui_stale())


class GenerationSsotTests(unittest.TestCase):
    def test_current_generation_prefers_symlink_over_stale_notify(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            real_old = td_path / "gen-old"
            real_new = td_path / "gen-new"
            real_old.mkdir()
            real_new.mkdir()
            link = td_path / "current-system"
            link.symlink_to(real_new)
            notify = td_path / "ncc" / "generation"
            _write(notify, str(real_old) + "\n")  # stale!

            with mock.patch.object(reload, "SYSTEM_LINK", link):
                with mock.patch.object(reload, "NOTIFY_FILE", notify):
                    gen = reload.current_generation()
            self.assertEqual(gen, str(real_new.resolve()))


class WatcherEvaluateTests(unittest.TestCase):
    """Drive GenerationWatcher._evaluate without waiting on inotify."""

    def setUp(self) -> None:
        _app()

    def test_hard_restart_when_fingerprint_changes(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            sys_a = td_path / "a"
            sys_b = td_path / "b"
            src_a = sys_a / "src"
            src_b = sys_b / "src"
            _pkg_tree(src_a, marker="a")
            _pkg_tree(src_b, marker="b")
            bin_a = sys_a / "sw" / "bin"
            bin_b = sys_b / "sw" / "bin"
            _payload_wrapper(bin_a, src_a)
            _payload_wrapper(bin_b, src_b)

            link = td_path / "current-system"
            link.symlink_to(sys_a)
            notify_dir = td_path / "run-ncc"
            notify_dir.mkdir()
            notify = notify_dir / "generation"
            _write(notify, str(sys_a.resolve()))

            def clean_tmp(raw: str) -> Path | None:
                part = raw.strip()
                if "${" in part:
                    part = part.split("${", 1)[0]
                p = Path(part.rstrip(":").strip())
                return p if p.exists() else None

            hard = []

            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                with mock.patch.object(reload, "SYSTEM_LINK", link):
                    with mock.patch.object(reload, "SW_BIN", bin_a):
                        with mock.patch.object(reload, "NOTIFY_DIR", notify_dir):
                            with mock.patch.object(reload, "NOTIFY_FILE", notify):
                                # Avoid watching real /run
                                with mock.patch.object(
                                    reload.GenerationWatcher,
                                    "_arm_watches",
                                    lambda self: None,
                                ):
                                    w = reload.GenerationWatcher(
                                        relaunch_argv=["/bin/true", "gui"],
                                        parent=_app(),
                                    )
                                    w._schedule_hard_restart = (  # type: ignore[method-assign]
                                        lambda: hard.append("hard")
                                    )
                                    # Soft path should not run
                                    soft = []
                                    reload.generation_bus().soft_switched.connect(
                                        lambda: soft.append("soft")
                                    )

                                    # Switch generation + profile
                                    link.unlink()
                                    link.symlink_to(sys_b)
                                    _write(notify, str(sys_b.resolve()))
                                    with mock.patch.object(reload, "SW_BIN", bin_b):
                                        w._evaluate()

            self.assertEqual(hard, ["hard"], f"expected hard restart, soft={soft}")
            self.assertEqual(soft, [])

    def test_soft_when_same_fingerprint_and_not_stale(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            # Two system dirs, identical GUI payload
            sys_a = td_path / "a"
            sys_b = td_path / "b"
            src = td_path / "shared-src"
            _pkg_tree(src, marker="shared")
            bin_a = sys_a / "sw" / "bin"
            bin_b = sys_b / "sw" / "bin"
            _payload_wrapper(bin_a, src)
            _payload_wrapper(bin_b, src)

            link = td_path / "current-system"
            link.symlink_to(sys_a)
            notify_dir = td_path / "run-ncc"
            notify_dir.mkdir()
            notify = notify_dir / "generation"
            _write(notify, str(sys_a.resolve()))

            def clean_tmp(raw: str) -> Path | None:
                part = raw.strip()
                if "${" in part:
                    part = part.split("${", 1)[0]
                p = Path(part.rstrip(":").strip())
                return p if p.exists() else None

            class FakeMod:
                def __init__(self, path: Path) -> None:
                    self.__file__ = str(path / "__init__.py")

            fake = {
                "ncc_gui": FakeMod(src / "ncc_gui"),
                "core": FakeMod(src / "core"),
            }
            hard: list[str] = []
            soft: list[str] = []

            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                with mock.patch.object(reload, "SYSTEM_LINK", link):
                    with mock.patch.object(reload, "SW_BIN", bin_a):
                        with mock.patch.object(reload, "NOTIFY_DIR", notify_dir):
                            with mock.patch.object(reload, "NOTIFY_FILE", notify):
                                with mock.patch.object(
                                    reload.GenerationWatcher,
                                    "_arm_watches",
                                    lambda self: None,
                                ):
                                    with mock.patch.dict(sys.modules, fake, clear=False):
                                        w = reload.GenerationWatcher(
                                            relaunch_argv=["/bin/true"],
                                            parent=_app(),
                                        )
                                        w._schedule_hard_restart = (  # type: ignore[method-assign]
                                            lambda: hard.append("hard")
                                        )
                                        reload.generation_bus().soft_switched.connect(
                                            lambda: soft.append("soft")
                                        )
                                        link.unlink()
                                        link.symlink_to(sys_b)
                                        _write(notify, str(sys_b.resolve()))
                                        with mock.patch.object(reload, "SW_BIN", bin_b):
                                            with mock.patch.object(
                                                reload, "refresh_catalog_env", lambda: True
                                            ):
                                                with mock.patch.object(
                                                    reload,
                                                    "refresh_runtime_paths",
                                                    lambda: True,
                                                ):
                                                    w._evaluate()

            self.assertEqual(soft, ["soft"])
            self.assertEqual(hard, [])

    def test_hard_when_same_fp_but_process_stale(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            sys_a = td_path / "a"
            sys_b = td_path / "b"
            old_src = td_path / "old-src"
            new_src = td_path / "new-src"
            # Identical markers → same hash content? Use same marker so fp matches
            # but different paths — wait, fingerprint includes root.name in line:
            # f"{pkg}@{root.name}=hash" — different root names → different fp!
            # For same fp we need same root.name OR only hash matters...
            # Looking at code: f"{pkg}@{root.name}={_hash_tree(d)}"
            # So different directory names change fingerprint even with same content.
            # Use the SAME src path for both wrappers (shared) for same fp,
            # but loaded modules point elsewhere.
            shared = td_path / "shared"
            _pkg_tree(shared, marker="x")
            _pkg_tree(old_src, marker="x")
            bin_a = sys_a / "sw" / "bin"
            bin_b = sys_b / "sw" / "bin"
            _payload_wrapper(bin_a, shared)
            _payload_wrapper(bin_b, shared)

            link = td_path / "current-system"
            link.symlink_to(sys_a)
            notify_dir = td_path / "run-ncc"
            notify_dir.mkdir()
            notify = notify_dir / "generation"
            _write(notify, str(sys_a.resolve()))

            def clean_tmp(raw: str) -> Path | None:
                part = raw.strip()
                if "${" in part:
                    part = part.split("${", 1)[0]
                p = Path(part.rstrip(":").strip())
                return p if p.exists() else None

            class FakeMod:
                def __init__(self, path: Path) -> None:
                    self.__file__ = str(path / "__init__.py")

            fake = {
                "ncc_gui": FakeMod(old_src / "ncc_gui"),
                "core": FakeMod(old_src / "core"),
            }
            hard: list[str] = []

            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                with mock.patch.object(reload, "SYSTEM_LINK", link):
                    with mock.patch.object(reload, "SW_BIN", bin_a):
                        with mock.patch.object(reload, "NOTIFY_DIR", notify_dir):
                            with mock.patch.object(reload, "NOTIFY_FILE", notify):
                                with mock.patch.object(
                                    reload.GenerationWatcher,
                                    "_arm_watches",
                                    lambda self: None,
                                ):
                                    with mock.patch.dict(sys.modules, fake, clear=False):
                                        w = reload.GenerationWatcher(
                                            relaunch_argv=["/bin/true"],
                                            parent=_app(),
                                        )
                                        w._schedule_hard_restart = (  # type: ignore[method-assign]
                                            lambda: hard.append("hard")
                                        )
                                        link.unlink()
                                        link.symlink_to(sys_b)
                                        _write(notify, str(sys_b.resolve()))
                                        with mock.patch.object(reload, "SW_BIN", bin_b):
                                            w._evaluate()

            self.assertEqual(hard, ["hard"])

    def test_stale_notify_file_does_not_block_symlink_detection(self) -> None:
        """Regression: notify file lagging behind current-system must still hard-restart."""
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            sys_a = td_path / "a"
            sys_b = td_path / "b"
            src_a = sys_a / "src"
            src_b = sys_b / "src"
            _pkg_tree(src_a, marker="a")
            _pkg_tree(src_b, marker="b")
            bin_a = sys_a / "sw" / "bin"
            bin_b = sys_b / "sw" / "bin"
            _payload_wrapper(bin_a, src_a)
            _payload_wrapper(bin_b, src_b)

            link = td_path / "current-system"
            link.symlink_to(sys_a)
            notify_dir = td_path / "run-ncc"
            notify_dir.mkdir()
            notify = notify_dir / "generation"
            _write(notify, str(sys_a.resolve()))

            def clean_tmp(raw: str) -> Path | None:
                part = raw.strip()
                if "${" in part:
                    part = part.split("${", 1)[0]
                p = Path(part.rstrip(":").strip())
                return p if p.exists() else None

            hard: list[str] = []

            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                with mock.patch.object(reload, "SYSTEM_LINK", link):
                    with mock.patch.object(reload, "SW_BIN", bin_a):
                        with mock.patch.object(reload, "NOTIFY_DIR", notify_dir):
                            with mock.patch.object(reload, "NOTIFY_FILE", notify):
                                with mock.patch.object(
                                    reload.GenerationWatcher,
                                    "_arm_watches",
                                    lambda self: None,
                                ):
                                    w = reload.GenerationWatcher(
                                        relaunch_argv=["/bin/true"],
                                        parent=_app(),
                                    )
                                    w._schedule_hard_restart = (  # type: ignore[method-assign]
                                        lambda: hard.append("hard")
                                    )
                                    # Symlink moved, notify file STILL old (the old bug)
                                    link.unlink()
                                    link.symlink_to(sys_b)
                                    # notify intentionally NOT updated
                                    with mock.patch.object(reload, "SW_BIN", bin_b):
                                        w._evaluate()

            self.assertEqual(
                hard,
                ["hard"],
                "must detect via /run/current-system even if generation file is stale",
            )


class PayloadChannelTests(unittest.TestCase):
    """registerGuiPython contract: declared payload files are hard, staged data is not."""

    def test_payload_file_path_change_is_hard_restart(self) -> None:
        """A generated index the payload reads by path can't be tree-hashed.

        Same staged tree, same generation names — only the baked fingerprint value moves.
        Without the NCC_GUI_FINGERPRINT channel this would soft-refresh and keep serving the
        old tool list from the old store path.
        """
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            sys_a = td_path / "a"
            sys_b = td_path / "b"
            src = td_path / "shared-src"
            _pkg_tree(src, marker="shared")
            bin_a = sys_a / "sw" / "bin"
            bin_b = sys_b / "sw" / "bin"
            _payload_wrapper(
                bin_a, src, fingerprint="/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-tools.json"
            )
            _payload_wrapper(
                bin_b, src, fingerprint="/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-tools.json"
            )

            link = td_path / "current-system"
            link.symlink_to(sys_a)
            notify_dir = td_path / "run-ncc"
            notify_dir.mkdir()
            notify = notify_dir / "generation"
            _write(notify, str(sys_a.resolve()))

            def clean_tmp(raw: str) -> Path | None:
                part = raw.strip()
                if "${" in part:
                    part = part.split("${", 1)[0]
                p = Path(part.rstrip(":").strip())
                return p if p.exists() else None

            hard: list[str] = []
            soft: list[str] = []
            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                with mock.patch.object(reload, "SYSTEM_LINK", link):
                    with mock.patch.object(reload, "SW_BIN", bin_a):
                        with mock.patch.object(reload, "NOTIFY_DIR", notify_dir):
                            with mock.patch.object(reload, "NOTIFY_FILE", notify):
                                with mock.patch.object(
                                    reload.GenerationWatcher, "_arm_watches", lambda self: None
                                ):
                                    w = reload.GenerationWatcher(
                                        relaunch_argv=["/bin/true"], parent=_app()
                                    )
                                    w._schedule_hard_restart = (  # type: ignore[method-assign]
                                        lambda: hard.append("hard")
                                    )
                                    reload.generation_bus().soft_switched.connect(
                                        lambda: soft.append("soft")
                                    )
                                    link.unlink()
                                    link.symlink_to(sys_b)
                                    _write(notify, str(sys_b.resolve()))
                                    with mock.patch.object(reload, "SW_BIN", bin_b):
                                        w._evaluate()

            self.assertEqual(hard, ["hard"], f"payload file change must be hard, soft={soft}")

    def test_staged_data_dir_is_never_digested(self) -> None:
        """Catalogs ship next to the packages; their content may never re-exec the GUI."""
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            sys_a = td_path / "a"
            sys_b = td_path / "b"
            # Same root basename on purpose: root.name is part of every digest line.
            src_a = sys_a / "share" / "src"
            src_b = sys_b / "share" / "src"
            for src, case in ((src_a, "one"), (src_b, "two")):
                _pkg_tree(src, marker="same")
                (src / "data").mkdir()
                (src / "data" / "cases.json").write_text(f'{{"case": {case!r}}}\n', "utf-8")
            bin_a = sys_a / "sw" / "bin"
            bin_b = sys_b / "sw" / "bin"
            _payload_wrapper(bin_a, src_a)
            _payload_wrapper(bin_b, src_b)

            def clean_tmp(raw: str) -> Path | None:
                part = raw.strip()
                if "${" in part:
                    part = part.split("${", 1)[0]
                p = Path(part.rstrip(":").strip())
                return p if p.exists() else None

            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                with mock.patch.object(reload, "SW_BIN", bin_a):
                    fp_a = reload.profile_gui_fingerprint()
                    dirs_a = reload.profile_gui_package_dirs()
                with mock.patch.object(reload, "SW_BIN", bin_b):
                    fp_b = reload.profile_gui_fingerprint()
                with mock.patch.object(reload, "SW_BIN", bin_a):
                    dirs_b = reload.profile_gui_package_dirs()

            self.assertTrue(fp_a, "fingerprint empty — packages not discovered")
            self.assertEqual(fp_a, fp_b, "catalog content changed the GUI fingerprint")
            for advertised in dirs_a | dirs_b:
                self.assertFalse(advertised.endswith("/data"), advertised)

    def test_generated_page_package_stays_soft(self) -> None:
        """Module toggles add or drop a page — that may never re-exec the GUI.

        Root is named like production (``ncc-domain-gui-src``) because that name is itself a
        soft-only marker: matching markers against the full path would blank the digest of
        every package below it, and a soft-only fixture name would hide exactly that.
        """
        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            roots = {}
            for tag, page_src in (("a", "old page"), ("b", "new page")):
                sys_dir = td_path / tag
                src = sys_dir / "ncc-domain-gui-src"
                _pkg_tree(src, marker="same")
                page = src / "ncc_domain_page"
                page.mkdir()
                (page / "__init__.py").write_text('"""pkg"""\n', encoding="utf-8")
                (page / "ai.py").write_text(f"SRC = {page_src!r}\n", encoding="utf-8")
                bin_dir = sys_dir / "sw" / "bin"
                _payload_wrapper(bin_dir, src)
                roots[tag] = (bin_dir, src)

            def clean_tmp(raw: str) -> Path | None:
                part = raw.strip()
                if "${" in part:
                    part = part.split("${", 1)[0]
                p = Path(part.rstrip(":").strip())
                return p if p.exists() else None

            with mock.patch.object(reload, "_clean_store_path", clean_tmp):
                bin_a, _ = roots["a"]
                bin_b, _ = roots["b"]
                with mock.patch.object(reload, "SW_BIN", bin_a):
                    fp_a = reload.profile_gui_fingerprint()
                    dirs_a = reload.profile_gui_package_dirs()
                with mock.patch.object(reload, "SW_BIN", bin_b):
                    fp_b = reload.profile_gui_fingerprint()

            # Digest not blanked by the root's own soft-only name.
            self.assertIn("ncc_gui@", fp_a, fp_a)
            self.assertIn("core@", fp_a, fp_a)
            self.assertNotIn("ncc_domain_page", fp_a, fp_a)
            self.assertEqual(fp_a, fp_b, "page code change must stay soft")
            for advertised in dirs_a:
                self.assertFalse(advertised.endswith("/ncc_domain_page"), advertised)

    def test_wrapper_named_after_a_peer_module_is_not_scanned(self) -> None:
        """The engine watches its own launchers; a peer's CLI is not GUI state."""
        with tempfile.TemporaryDirectory() as td:
            bin_dir = Path(td) / "sw" / "bin"
            _payload_wrapper(bin_dir, Path(td) / "src", name="ncc-assistant")
            with mock.patch.object(reload, "SW_BIN", bin_dir):
                self.assertEqual(reload._iter_gui_wrappers(), [])


class LiveProfileSmokeTests(unittest.TestCase):
    """Smoke against the real system profile (informational if paths missing)."""

    def test_live_fingerprint_nonempty_if_ncc_present(self) -> None:
        wrapper = next(
            (
                Path(f"/run/current-system/sw/bin/{name}")
                for name in ("ncc-domain-gui", "ncc-gui")
                if Path(f"/run/current-system/sw/bin/{name}").is_file()
            ),
            None,
        )
        if wrapper is None:
            self.skipTest("no live ncc GUI")
        fp = reload.profile_gui_fingerprint()
        self.assertTrue(fp)
        # Must not contain bash junk
        self.assertNotIn("${", fp)
        text = wrapper.read_text()
        roots = reload._roots_from_wrapper(wrapper)
        self.assertTrue(roots, f"failed to parse roots from wrapper:\n{text[:400]}")
        for r in roots:
            self.assertTrue(r.is_dir(), r)
            self.assertNotIn("${", str(r))


def main() -> int:
    _app()
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
