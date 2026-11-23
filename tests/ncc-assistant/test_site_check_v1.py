"""Site-check wave v1 — domain attach + static scanner helpers.

Behaviour under test: ``normalize_domain`` / ``set_workspace_domains``;
``check_url`` findings on mocked HTML; private hosts refused; CLI/UI surface
strings. Module: ``core.workflows.site_check`` + ``core.store.workspaces``.

Existing tests: none for site-check (github agent autonomy covers docs stubs only).
User: "workflow wave … domains adden … checks … fr4iser.com oder scan.fr4iser.com".
"""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2] / "nixos/modules/specialized/ncc-assistant"


class SiteCheckV1Tests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory(prefix="ncc-site-check-")
        self._prev = os.environ.get("XDG_CONFIG_HOME")
        self.addCleanup(self._restore)
        self.addCleanup(self._td.cleanup)
        os.environ["XDG_CONFIG_HOME"] = self._td.name
        self._repo = Path(self._td.name) / "repo"
        self._repo.mkdir()

    def _restore(self) -> None:
        if self._prev is None:
            os.environ.pop("XDG_CONFIG_HOME", None)
        else:
            os.environ["XDG_CONFIG_HOME"] = self._prev

    def test_normalize_and_attach_domains(self) -> None:
        from core.store.workspaces import (
            normalize_domain,
            set_workspace_domains,
            upsert_workspace,
            workspaces_with_domains,
        )

        self.assertEqual(normalize_domain("Scan.Fr4iser.Com"), "scan.fr4iser.com")
        self.assertEqual(
            normalize_domain("https://fr4iser.com/kontakt/"),
            "https://fr4iser.com/kontakt",
        )
        upsert_workspace("demo", str(self._repo), label="demo")
        ws = set_workspace_domains("demo", ["scan.fr4iser.com", "https://fr4iser.com/"])
        self.assertEqual(ws.domains, ["scan.fr4iser.com", "fr4iser.com"])
        self.assertEqual([w.id for w in workspaces_with_domains()], ["demo"])

    def test_private_host_refused(self) -> None:
        from core.workflows.site_check import check_url

        with self.assertRaises(ValueError):
            check_url("http://127.0.0.1/")

    def test_check_url_parses_headers_and_seo(self) -> None:
        from core.workflows.site_check import check_url

        html = (
            "<html lang='en'><head><title>Demo</title>"
            "<meta name='viewport' content='width=device-width'>"
            "<meta name='description' content='hi'>"
            "<link rel='canonical' href='https://example.com/'>"
            "</head><body><h1>Hi</h1>"
            "<script src='https://cdn.example.net/x.js'></script>"
            "</body></html>"
        )
        headers = {
            "Server": "nginx/1.27.5",
            "Strict-Transport-Security": "max-age=31536000",
            "Content-Security-Policy": "default-src 'self'",
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "SAMEORIGIN",
            "Referrer-Policy": "strict-origin-when-cross-origin",
            "Permissions-Policy": "camera=()",
        }

        def fake_fetch(url: str, *, follow: bool = True):
            if url.startswith("http://"):
                return {
                    "ok": True,
                    "url": "https://example.com/",
                    "status": 200,
                    "headers": {},
                    "body": "",
                }
            return {
                "ok": True,
                "url": "https://example.com/",
                "status": 200,
                "headers": {k.lower(): v for k, v in headers.items()},
                "body": html,
            }

        with mock.patch("core.workflows.site_check._assert_public_host"), mock.patch(
            "core.workflows.site_check._fetch", side_effect=fake_fetch
        ), mock.patch(
            "core.workflows.site_check._tls_info",
            return_value={
                "ok": True,
                "tlsVersion": "TLSv1.3",
                "issuer": "Test",
                "notAfter": "Dec 15 12:00:00 2026 GMT",
                "daysLeft": 40,
                "sans": ["example.com"],
            },
        ):
            result = check_url("example.com")
        self.assertEqual(result["status"], 200)
        self.assertEqual(result["securityHeaders"]["score"], "6/6")
        self.assertIn("server_version_exposed", result["findings"])
        self.assertTrue(
            any(f.startswith("external_sources:") for f in result["findings"])
        )
        self.assertTrue(result["httpToHttps"])

    def test_cli_and_surface_strings(self) -> None:
        cli = (ROOT / "cli" / "cli.py").read_text(encoding="utf-8")
        self.assertIn("def _cmd_site_check", cli)
        self.assertIn('"site-check"', cli)
        self.assertIn("workspaces domains", cli)
        cmds = (ROOT / "commands.nix").read_text(encoding="utf-8")
        self.assertIn("site-check", cmds)
        panel = (ROOT / "widgets" / "github_agent_panel.py").read_text(encoding="utf-8")
        self.assertIn("Site-check wave", panel)
        self.assertIn("Domains…", panel)
        widgets = (ROOT / "widgets" / "github_agent.py").read_text(encoding="utf-8")
        self.assertIn("class GithubAgentDomainsDialog", widgets)
        window = (ROOT / "companion" / "window.py").read_text(encoding="utf-8")
        self.assertIn("_github_agent_site_check", window)
        self.assertIn("_github_agent_domains_dialog", window)


if __name__ == "__main__":
    unittest.main()
