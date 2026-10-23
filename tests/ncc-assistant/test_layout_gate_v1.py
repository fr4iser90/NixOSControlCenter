#!/usr/bin/env python3
"""Negative proof for `tests/gates/validate-assistant-layout.sh`.

A gate that has never been attacked is an unverified claim, so every check in that script gets
one injected violation here and must go red on it. The control case (`test_control_*`) is what
makes the attacks meaningful: it proves the fixture is faithful, so a red run can only come
from the injected violation and not from the fixture being broken.

Attacks aim at the failure modes the tree plan actually creates:

  staging    a package hoisted to the staging root, i.e. a new PYTHONPATH importable
  stdlib     a hoisted name that shadows a stdlib module
  sys.path   the mechanism that would make every submodule name importable
  data/      catalog dirs growing into a package
  loaders    the silent `return []` when a catalog leaves the importable package
  entrypoint a wrapper renamed away from the one target, and an import that breaks at startup
  ratchet    a new module dropped into the flat pile

The gate takes `NCC_ASSISTANT_MODULE_DIR`, so each case copies the module and attacks the copy:
no test here mutates the checkout.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GATE = REPO / "tests/gates/validate-assistant-layout.sh"
MODULE = REPO / "nixos/modules/specialized/ncc-assistant"

PKG_ANCHOR_STAGING = "    cp -r ${./python/ncc_assistant} $out/ncc_assistant"
PKG_ANCHOR_MCP = "    exec ${pythonEnv}/bin/python -m ncc_assistant mcp"


class LayoutGateBiteTests(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        self.assertTrue(GATE.is_file(), f"gate missing: {GATE}")
        tmp = Path(self.enterContext(tempfile.TemporaryDirectory(prefix="ncc-layout-fixture-")))
        self.fixture = tmp / "module"
        self.fixture.mkdir()
        shutil.copy2(MODULE / "package.nix", self.fixture / "package.nix")
        shutil.copytree(
            MODULE / "python",
            self.fixture / "python",
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        shutil.copytree(MODULE / "data", self.fixture / "data")
        self.pkg = self.fixture / "package.nix"
        self.pkg_text = self.pkg.read_text(encoding="utf-8")

    # ── harness ───────────────────────────────────────────────────────────────

    def run_gate(self) -> subprocess.CompletedProcess[str]:
        env = dict(os.environ)
        env["NCC_ASSISTANT_MODULE_DIR"] = str(self.fixture)
        env["NCC_ASSISTANT_PYTHON"] = sys.executable
        # The gate must judge the fixture only; an inherited path could make it import the
        # real checkout and pass for the wrong reason.
        env.pop("PYTHONPATH", None)
        return subprocess.run(
            ["bash", str(GATE)],
            capture_output=True,
            text=True,
            env=env,
            cwd=str(REPO),
            timeout=300,
        )

    def attack_package(self, old: str, new: str) -> None:
        self.assertIn(old, self.pkg_text, "attack anchor moved in package.nix")
        self.pkg.write_text(self.pkg_text.replace(old, new), encoding="utf-8")

    def attack_python(self, rel: str, old: str, new: str) -> None:
        path = self.fixture / "python" / "ncc_assistant" / rel
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text, f"attack anchor moved in {rel}")
        path.write_text(text.replace(old, new), encoding="utf-8")

    def assert_red(self, expect: str) -> str:
        proc = self.run_gate()
        out = proc.stdout + proc.stderr
        self.assertNotEqual(proc.returncode, 0, f"gate stayed green — it does not bite.\n{out}")
        self.assertIn(
            expect,
            out,
            f"gate went red, but not on the check under test ({expect!r}).\n{out}",
        )
        # An abort (set -e, missing command) is not a verdict: require the named summary.
        self.assertIn("validate-assistant-layout summary", out)
        return out

    # ── control ───────────────────────────────────────────────────────────────

    def test_control_unattacked_fixture_is_green(self) -> None:
        proc = self.run_gate()
        self.assertEqual(
            proc.returncode,
            0,
            "the fixture itself does not pass the gate — every attack below would be "
            f"indistinguishable from fixture noise.\n{proc.stdout}{proc.stderr}",
        )

    # ── 1) staging Soll-Menge ─────────────────────────────────────────────────

    def test_hoisting_a_package_to_the_staging_root_is_caught(self) -> None:
        self.attack_package(
            PKG_ANCHOR_STAGING,
            PKG_ANCHOR_STAGING + "\n    cp -r $out/ncc_assistant/plugins $out/plugins",
        )
        self.assert_red("appRoot top level changed")

    # ── 2) stdlib shadowing / sys.path ────────────────────────────────────────

    def test_a_stdlib_shadowing_top_level_name_is_caught(self) -> None:
        self.attack_package(
            PKG_ANCHOR_STAGING,
            PKG_ANCHOR_STAGING + "\n    cp -r $out/ncc_assistant/plugins $out/types",
        )
        self.assert_red("shadowing stdlib at importable top level: types")

    def test_editing_sys_path_is_caught(self) -> None:
        """Not decoration: this is the one mechanism that turns an ordinary submodule name
        into an importable one, which is what would silently void check 2."""
        self.attack_python(
            "paths.py",
            "def config_home() -> Path:",
            "def config_home() -> Path:\n    import sys as _sys\n    _sys.path.insert(0, str(__package__ and '.'))",
        )
        self.assert_red("sys.path was edited")

    # ── 3) data/ stays code-free ──────────────────────────────────────────────

    def test_python_under_data_is_caught(self) -> None:
        (self.fixture / "data" / "playbooks" / "loader.py").write_text("# noqa\n", encoding="utf-8")
        self.assert_red("data/ must stay catalog-only")

    # ── 4) loader degradation + provenance ────────────────────────────────────

    def test_catalog_moved_out_of_the_package_is_caught(self) -> None:
        """The plan's central risk, in one move: `playbooks/` relocates and the loader starts
        answering `[]`. Nothing prints an error, so only the gate notices."""
        shutil.rmtree(self.fixture / "python" / "ncc_assistant" / "playbooks")
        self.assert_red("playbooks: loader returned 0 playbooks")

    def test_cases_moved_out_of_the_package_is_caught(self) -> None:
        (self.fixture / "python" / "ncc_assistant" / "eval" / "cases.json").write_text(
            "[]", encoding="utf-8"
        )
        self.assert_red("eval: loader returned 0 cases")

    def test_a_loader_reading_outside_the_tree_is_caught(self) -> None:
        """Provenance, not just non-emptiness: the loader here reads the *real* checkout, so a
        check that only counted cases would call this fine."""
        real_cases = (MODULE / "python" / "ncc_assistant" / "eval" / "cases.json").resolve()
        self.attack_python(
            "eval_harness.py",
            '    packaged = Path(__file__).resolve().parent / "eval" / "cases.json"',
            f'    packaged = Path({str(real_cases)!r})',
        )
        self.assert_red("source outside the tree")

    # ── 5) entrypoints ────────────────────────────────────────────────────────

    def test_a_wrapper_on_its_own_target_is_caught(self) -> None:
        self.attack_package(PKG_ANCHOR_MCP, PKG_ANCHOR_MCP.replace("ncc_assistant mcp", "ncc_mcp"))
        self.assert_red("wrappers bind more than one module")

    def test_an_entrypoint_that_fails_to_start_is_caught(self) -> None:
        """Renaming alone is not enough — a wrapper can point at the right module and still
        die on import. That is what the smoke is for, so it is attacked directly."""
        self.attack_python(
            "__main__.py",
            "from .cli import main",
            "import ncc_assistant.module_deleted_by_the_refactor  # noqa\nfrom .cli import main",
        )
        self.assert_red("entrypoint smoke")

    # ── 6) ratchet ────────────────────────────────────────────────────────────

    def test_a_new_top_level_module_is_caught(self) -> None:
        (self.fixture / "python" / "ncc_assistant" / "another_flat_module.py").write_text(
            "# noqa\n", encoding="utf-8"
        )
        self.assert_red("package top level grew to")


if __name__ == "__main__":
    unittest.main()
