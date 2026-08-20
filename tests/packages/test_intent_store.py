"""Unit tests for packages Store intent matching (no Nix required)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

GUI_DIR = Path(__file__).resolve().parents[2] / "nixos/core/base/packages/ui/gui"
sys.path.insert(0, str(GUI_DIR))

from intent_store import (  # noqa: E402
    format_intent_details,
    install_status,
    is_store_intent,
    score_intent,
    search_intents,
    stage_argv_for_intent,
    store_intents,
)


SAMPLE = {
    "categories": [
        {"id": "dev", "title": "Development"},
        {"id": "media", "title": "Media"},
        {"id": "games", "title": "Games"},
    ],
    "intents": [
        {
            "id": "vscode",
            "title": "VS Code",
            "aliases": ["vscode", "code", "vs code"],
            "description": "Visual Studio Code",
            "category": "dev",
            "kind": "attr",
            "scope": "user",
            "attr": "vscode",
            "module": None,
            "partOfSet": None,
            "tryable": True,
            "requiresAdmin": False,
            "requiresUnfree": True,
            "related": [],
            "notes": "",
        },
        {
            "id": "obs",
            "title": "OBS Studio",
            "aliases": ["obs", "obs studio"],
            "description": "Open Broadcaster Software",
            "category": "media",
            "kind": "attr",
            "scope": "user",
            "attr": "obs-studio",
            "module": None,
            "partOfSet": "streaming",
            "tryable": True,
            "requiresAdmin": False,
            "requiresUnfree": False,
            "related": [],
            "notes": "user app; set streaming is separate",
        },
        {
            "id": "steam",
            "title": "Steam",
            "aliases": ["steam", "valve"],
            "description": "Steam client",
            "category": "games",
            "kind": "attr",
            "scope": "user",
            "attr": "steam",
            "module": None,
            "partOfSet": "gaming",
            "tryable": True,
            "requiresAdmin": False,
            "requiresUnfree": True,
            "related": [],
            "notes": "",
        },
        {
            "id": "wow",
            "title": "World of Warcraft",
            "aliases": ["wow", "world of warcraft", "battle.net"],
            "description": "Game",
            "category": "games",
            "kind": "guided",
            "scope": "user",
            "attr": None,
            "module": None,
            "partOfSet": "gaming",
            "tryable": False,
            "requiresAdmin": False,
            "requiresUnfree": True,
            "related": ["lutris"],
            "notes": "via Lutris",
        },
        {
            "id": "legacy-set",
            "title": "Should not appear in store",
            "aliases": ["legacy set"],
            "description": "old set intent",
            "category": "media",
            "kind": "set",
            "scope": "system",
            "attr": None,
            "module": "streaming",
            "tryable": False,
            "requiresAdmin": True,
            "requiresUnfree": False,
            "related": [],
            "notes": "",
        },
    ],
}


class IntentStoreTests(unittest.TestCase):
    def test_vscode_aliases(self) -> None:
        hits = search_intents(SAMPLE, "vs code")
        self.assertTrue(hits)
        self.assertEqual(hits[0]["id"], "vscode")
        self.assertEqual(score_intent("code", SAMPLE["intents"][0]), 100)

    def test_obs_stages_user_attr(self) -> None:
        hits = search_intents(SAMPLE, "obs")
        self.assertEqual(hits[0]["id"], "obs")
        staged = stage_argv_for_intent(hits[0])
        assert staged is not None
        summary, argv, elevated = staged
        self.assertEqual(summary, "add obs-studio")
        self.assertEqual(argv[:3], ["packages", "add", "obs-studio"])
        self.assertFalse(elevated)
        self.assertEqual(hits[0].get("partOfSet"), "streaming")

    def test_steam_is_store_attr(self) -> None:
        hits = search_intents(SAMPLE, "steam")
        self.assertEqual(hits[0]["id"], "steam")
        self.assertTrue(is_store_intent(hits[0]))
        staged = stage_argv_for_intent(hits[0])
        assert staged is not None
        self.assertEqual(staged[1][:3], ["packages", "add", "steam"])
        self.assertFalse(staged[2])

    def test_wow_guided_does_not_stage(self) -> None:
        hits = search_intents(SAMPLE, "world of warcraft")
        self.assertEqual(hits[0]["id"], "wow")
        self.assertIsNone(stage_argv_for_intent(hits[0]))

    def test_store_filters_out_sets(self) -> None:
        hits = search_intents(SAMPLE, "legacy")
        self.assertEqual(hits, [])
        self.assertTrue(all(is_store_intent(it) for it in store_intents(SAMPLE)))
        self.assertFalse(any(it["id"] == "legacy-set" for it in store_intents(SAMPLE)))

    def test_install_status_user_and_set(self) -> None:
        obs = next(i for i in SAMPLE["intents"] if i["id"] == "obs")
        missing = install_status(obs, mine=[], active_sets=[])
        self.assertEqual(missing["state"], "missing")
        user = install_status(obs, mine=["obs-studio"], active_sets=[])
        self.assertEqual(user["state"], "user")
        self.assertIn("✓", "✓" if user["via_user"] else "")
        via_set = install_status(obs, mine=[], active_sets=["streaming"])
        self.assertEqual(via_set["state"], "set")
        both = install_status(obs, mine=["obs-studio"], active_sets=["streaming"])
        self.assertEqual(both["state"], "both")
        details = format_intent_details(obs, status=user)
        self.assertIn("Status:", details)
        self.assertIn("nixpkgs pin", details)


if __name__ == "__main__":
    unittest.main()
