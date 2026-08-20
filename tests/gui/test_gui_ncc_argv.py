"""Validate every DomainPage footer button declares a registered ``ncc`` path.

Contract (enforced by ``DomainPage.add_action`` + this suite):

* ``ncc=("domain", "verb", …)`` — first two tokens must exist as
  ``parent=domain`` / ``name=verb`` in cli-registry (else dispatcher:
  ``Unknown command 'domain verb'``).
* ``local=True`` — UI-only (Refresh, dialogs, raw ssh, commit staging).

Scans all ``ui/gui/**/*.py`` (+ kit pages) so *every* ``add_action`` call is
classified; undeclared buttons fail the suite.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
NIXOS = REPO / "nixos"

NAME_RE = re.compile(r'name\s*=\s*"([^"]+)"')
PARENT_RE = re.compile(r'parent\s*=\s*"([^"]+)"')
NCC_KW = re.compile(
    r"""ncc\s*=\s*(?:\(|\[)\s*["']([a-z][a-z0-9-]*)["']"""
    r"""(?:\s*,\s*["']([a-z][a-z0-9-]*)["'])?""",
    re.MULTILINE,
)


def _repo_commands() -> tuple[set[str], set[tuple[str, str]]]:
    tops: set[str] = set()
    children: set[tuple[str, str]] = set()
    for root in (NIXOS / "core", NIXOS / "modules"):
        if not root.is_dir():
            continue
        for path in root.rglob("*.nix"):
            text = path.read_text(encoding="utf-8", errors="replace")
            if "registerCommandsFor" not in text and "parent =" not in text:
                continue
            for block in re.split(r"\n\s*\{\s*\n", text):
                names = NAME_RE.findall(block)
                parents = PARENT_RE.findall(block)
                if not names:
                    continue
                name = names[0]
                if parents:
                    children.add((parents[0], name))
                elif "registerCommandsFor" in text:
                    tops.add(name)
    return tops, children


def _call_span(text: str, open_paren: int) -> str:
    """Return source from ``(`` at open_paren through matching ``)``."""
    depth = 0
    i = open_paren
    while i < len(text):
        ch = text[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return text[open_paren : i + 1]
        elif ch in "'\"":
            quote = ch
            i += 1
            while i < len(text) and text[i] != quote:
                if text[i] == "\\" and i + 1 < len(text):
                    i += 2
                    continue
                i += 1
        i += 1
    raise ValueError("unbalanced add_action(…)")


def _gui_page_files() -> list[Path]:
    pages = list(NIXOS.rglob("ui/gui/**/*.py"))
    kit = NIXOS / "core/management/gui-engine/python/ncc_gui/pages"
    if kit.is_dir():
        pages.extend(kit.rglob("*.py"))
    return [p for p in pages if p.is_file()]


def _add_action_calls() -> list[tuple[Path, int, str]]:
    """(file, line, call_body) for every ``.add_action(``."""
    out: list[tuple[Path, int, str]] = []
    for path in _gui_page_files():
        text = path.read_text(encoding="utf-8")
        for m in re.finditer(r"\.add_action\(", text):
            body = _call_span(text, m.end() - 1)
            line = text[: m.start()].count("\n") + 1
            out.append((path, line, body))
    return out


class TestGuiDeclaredActions(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tops, cls.children = _repo_commands()
        cls.calls = _add_action_calls()

    def test_every_add_action_is_declared(self) -> None:
        bad: list[str] = []
        for path, line, body in self.calls:
            has_ncc = re.search(r"\bncc\s*=", body) is not None
            has_local = re.search(r"\blocal\s*=\s*True\b", body) is not None
            if has_ncc or has_local:
                continue
            rel = path.relative_to(REPO)
            bad.append(f"{rel}:{line}: add_action missing ncc=… or local=True")
        self.assertEqual(
            bad,
            [],
            "Every footer button must declare ncc=(domain, verb, …) or local=True:\n  "
            + "\n  ".join(bad),
        )

    def test_declared_ncc_verbs_are_registered(self) -> None:
        bad: list[str] = []
        for path, line, body in self.calls:
            m = NCC_KW.search(body)
            if not m:
                continue
            domain, verb = m.group(1), m.group(2)
            if verb is None:
                # Domain-only declaration: top-level manager must exist.
                if domain not in self.tops and domain not in {p for p, _ in self.children}:
                    rel = path.relative_to(REPO)
                    bad.append(f"{rel}:{line}: unknown domain ncc=({domain!r})")
                continue
            if verb.startswith("-"):
                continue
            if (domain, verb) in self.children:
                continue
            rel = path.relative_to(REPO)
            bad.append(
                f"{rel}:{line}: ncc {domain} {verb} not registered "
                f"(need parent={domain!r} name={verb!r})"
            )
        self.assertEqual(
            bad,
            [],
            "Declared button ncc= paths must match cli-registry children:\n  "
            + "\n  ".join(bad),
        )

    def test_install_shell_regression(self) -> None:
        need = {("install", "wizard"), ("install", "dry-run"), ("install", "shell")}
        missing = sorted(need - self.children)
        self.assertEqual(missing, [], f"install children missing: {missing}")
        found = {
            (m.group(1), m.group(2))
            for _, _, body in self.calls
            for m in [NCC_KW.search(body)]
            if m and m.group(2)
        }
        self.assertTrue(
            need <= found,
            f"Install page must declare {need}; found among GUI: {need & found}",
        )


if __name__ == "__main__":
    unittest.main()
