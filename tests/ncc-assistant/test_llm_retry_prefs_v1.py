#!/usr/bin/env python3
"""LLM timeout/retry preferences + wiring."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant import preferences as prefs  # noqa: E402
from ncc_assistant.llm import (  # noqa: E402
    LLMError,
    _is_transient_llm_error,
    _max_attempts,
    _request_timeout,
)


class LlmPrefsTests(unittest.TestCase):
    def test_timeout_retries_roundtrip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "preferences.json"
            with patch.object(prefs, "preferences_file", return_value=path):
                self.assertEqual(prefs.get_llm_timeout_sec(), 300)
                self.assertEqual(prefs.get_llm_retries(), 1)
                prefs.set_llm_timeout_sec(120)
                prefs.set_llm_retries(3)
                self.assertEqual(prefs.get_llm_timeout_sec(), 120)
                self.assertEqual(prefs.get_llm_retries(), 3)
                prefs.set_llm_timeout_sec(10)  # clamp
                self.assertEqual(prefs.get_llm_timeout_sec(), 30)
                prefs.set_llm_retries(99)
                self.assertEqual(prefs.get_llm_retries(), 5)

    def test_request_timeout_reads_prefs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "preferences.json"
            with patch.object(prefs, "preferences_file", return_value=path):
                prefs.set_llm_timeout_sec(90)
                t = _request_timeout()
                self.assertEqual(float(t.read), 90.0)
                prefs.set_llm_retries(2)
                self.assertEqual(_max_attempts(), 3)

    def test_transient_detection(self) -> None:
        self.assertTrue(_is_transient_llm_error(LLMError("boom", status_code=503)))
        self.assertTrue(_is_transient_llm_error(LLMError("rate limit exceeded")))
        self.assertFalse(_is_transient_llm_error(LLMError("bad request", status_code=400)))


class RetryUiAstTests(unittest.TestCase):
    def test_companion_has_retry(self) -> None:
        text = (ROOT / "ncc_assistant" / "companion.py").read_text(encoding="utf-8")
        self.assertIn("self.retry_btn", text)
        self.assertIn("def _retry", text)
        self.assertIn("if not slot.last_error:", text)

    def test_gui_has_retry_and_settings(self) -> None:
        gui = (ROOT / "ncc_assistant" / "gui.py").read_text(encoding="utf-8")
        self.assertIn("def on_retry", gui)
        self.assertIn("self.retry_btn", gui)
        settings = (ROOT / "ncc_assistant" / "gui_pages.py").read_text(encoding="utf-8")
        self.assertIn("4c · LLM request", settings)
        self.assertIn("set_llm_timeout_sec", settings)
        self.assertIn("set_llm_retries", settings)


if __name__ == "__main__":
    unittest.main()
