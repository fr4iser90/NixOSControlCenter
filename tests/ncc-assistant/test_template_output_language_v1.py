#!/usr/bin/env python3
"""Doc-writing agent templates expose a Language param (default English).

Guards three things at once: the dropdown exists where prose is written, it is absent
where the output is canonical or machine-format, and the choice really reaches the goal.
"""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant import agent_templates as at  # noqa: E402
from ncc_assistant import workspaces as ws_mod  # noqa: E402

PARAM_ID = "outputLanguage"
OPTIONS = ["English", "Deutsch", "Auto (keep file)"]

# Templates that write prose into a workspace.
DOC_WRITERS = (
    "agents-md-maintainer",
    "agents-md-creator",
    "skills-maintainer",
    "skill-pack-creator",
    "roadmap-creator",
    "changelog-creator",
    "contributing-creator",
    "security-md-creator",
    "impressum-creator",
    "privacy-policy-creator",
    "design-concept-creator",
)

# SPDX texts and config files must not be translated into another language.
NOT_DOC_WRITERS = (
    "license-chooser",
    "gitignore-creator",
    "editorconfig-creator",
    "precommit-creator",
    "githooks-creator",
    "github-actions-creator",
    "codeowners-creator",
)


class OutputLanguageParamTests(unittest.TestCase):
    def _tmpl(self, tid: str):
        tmpl = at.get_agent_template(tid)
        self.assertIsNotNone(tmpl, tid)
        assert tmpl is not None
        return tmpl

    def _param(self, tid: str):
        for p in self._tmpl(tid).params:
            if p.id == PARAM_ID:
                return p
        self.fail(f"{tid}: no {PARAM_ID} param")

    def test_doc_writers_offer_language_defaulting_to_english(self) -> None:
        for tid in DOC_WRITERS:
            with self.subTest(tid):
                p = self._param(tid)
                self.assertEqual(p.type, "enum")
                self.assertEqual(p.label, "Language")
                self.assertEqual(p.options, OPTIONS)
                self.assertEqual(p.default, "English")
                self.assertTrue(p.required)

    def test_every_doc_writer_goal_uses_the_choice(self) -> None:
        for tid in DOC_WRITERS:
            with self.subTest(tid):
                self.assertIn("{{" + PARAM_ID + "}}", self._tmpl(tid).goal_template)

    def test_config_and_license_generators_stay_language_free(self) -> None:
        for tid in NOT_DOC_WRITERS:
            with self.subTest(tid):
                tmpl = self._tmpl(tid)
                self.assertNotIn(PARAM_ID, [p.id for p in tmpl.params])
                self.assertNotIn("{{" + PARAM_ID, tmpl.goal_template)


class OutputLanguageRenderingTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.cfg = Path(self._tmp.name)
        self.env_patch = patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.cfg)})
        self.env_patch.start()
        repo = self.cfg / "repo"
        repo.mkdir()
        ws_mod.upsert_workspace("demo", str(repo))

    def tearDown(self) -> None:
        self.env_patch.stop()
        self._tmp.cleanup()

    def test_omitted_param_still_renders_the_default(self) -> None:
        # instantiate() merges p.default, so a CLI run cannot leak a raw placeholder.
        result = at.instantiate(
            "agents-md-maintainer",
            {"checkFrequency": "weekly", "timezone": "UTC", "repositories": ["demo"]},
            instance_id="lang-default",
        )
        self.assertTrue(result["ok"], result)
        self.assertIn("Write and summarise in English.", result["goal"])
        self.assertNotIn("{{", result["goal"])

    def test_choice_reaches_the_goal(self) -> None:
        tmpl = at.get_agent_template("agents-md-creator")
        assert tmpl is not None
        goal = at.render_goal(tmpl, {PARAM_ID: "Deutsch", "repositories": []})
        self.assertIn("Language: Deutsch.", goal)
        self.assertNotIn("{{" + PARAM_ID + "}}", goal)

    def test_language_outside_the_enum_is_rejected(self) -> None:
        tmpl = at.get_agent_template("changelog-creator")
        assert tmpl is not None
        errors = at.validate_instance_params(
            tmpl,
            {
                PARAM_ID: "Klingon",
                "style": "simple",
                "outputFile": "CHANGELOG.md",
            },
        )
        self.assertTrue(any("Language" in e for e in errors), errors)


class PortableMaintainerSkillTests(unittest.TestCase):
    def test_agents_md_skill_does_not_hardcode_one_project(self) -> None:
        text = at.load_skill_text("skills/agents-md-maintainer.md")
        self.assertIn("AGENTS.md", text)
        self.assertIn("tool-agnostic", text)
        self.assertIn("source of truth", text)
        for project_only in ("/etc/nixos", "run-gates.sh", "getModuleConfig", "nixos/"):
            self.assertNotIn(project_only, text)

    def test_skills_skill_defers_to_the_repository_laws(self) -> None:
        text = at.load_skill_text("skills/skills-maintainer.md")
        self.assertIn("repository's own root", text)
        self.assertNotIn("NCC", text)


if __name__ == "__main__":
    unittest.main()
