#!/usr/bin/env python3
"""Phase 35 doomscroll / focus watchdog (no display)."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))


class FocusWatchdogTests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        home = Path(self._td.name)
        self._patch = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home)})
        self._patch.start()
        self.addCleanup(self._patch.stop)
        from ncc_assistant.preferences import (
            set_doomscroll_after_min,
            set_doomscroll_apps,
            set_doomscroll_cooldown_min,
            set_doomscroll_enable,
            set_doomscroll_match_mode,
            set_doomscroll_site_pack,
            set_doomscroll_style,
        )

        set_doomscroll_enable(True)
        set_doomscroll_after_min(5)
        set_doomscroll_cooldown_min(5)
        set_doomscroll_style("nudge")
        set_doomscroll_apps(["firefox"])
        set_doomscroll_match_mode("browser-sites")
        set_doomscroll_site_pack("social+video")

    def test_match_youtube_shorts(self) -> None:
        from ncc_assistant.focus import is_doomscroll_window
        from ncc_assistant.preferences import set_doomscroll_site_pack

        set_doomscroll_site_pack("youtube-shorts")
        self.assertTrue(
            is_doomscroll_window(
                {"class": "firefox", "title": "Funny cat #Shorts - YouTube"}
            )
        )
        self.assertFalse(
            is_doomscroll_window(
                {"class": "firefox", "title": "Long lecture - YouTube"}
            )
        )
        # Plasma+Firefox live evidence: caption has no "Shorts", only MPRIS URL.
        self.assertTrue(
            is_doomscroll_window(
                {
                    "class": "firefox",
                    "title": "Ranking Funniest Low Quality Videos - YouTube — Mozilla Firefox",
                    "url": "https://www.youtube.com/shorts/rYlcr-Wkd7E",
                }
            )
        )

    def test_detect_desktop_exclusive(self) -> None:
        from ncc_assistant import focus

        with mock.patch.dict(
            os.environ,
            {
                "HYPRLAND_INSTANCE_SIGNATURE": "abc",
                "XDG_CURRENT_DESKTOP": "KDE",
                "SWAYSOCK": "",
            },
            clear=False,
        ):
            with mock.patch.object(focus, "_kwin_on_bus", return_value=True):
                self.assertEqual(focus.detect_desktop(), "hyprland")

        with mock.patch.dict(
            os.environ,
            {
                "HYPRLAND_INSTANCE_SIGNATURE": "",
                "SWAYSOCK": "",
                "XDG_CURRENT_DESKTOP": "KDE",
                "DESKTOP_SESSION": "plasma",
                "WAYLAND_DISPLAY": "wayland-0",
                "XDG_SESSION_TYPE": "wayland",
            },
            clear=False,
        ):
            with mock.patch.object(focus, "_kwin_on_bus", return_value=True):
                self.assertEqual(focus.detect_desktop(), "plasma-wayland")

    def test_get_active_window_uses_only_plasma_adapter(self) -> None:
        from ncc_assistant import focus

        plasma_win = {
            "class": "firefox",
            "title": "Short - YouTube",
            "url": "https://www.youtube.com/shorts/x",
            "source": "plasma-mpris",
            "desktop": "plasma-wayland",
        }
        with mock.patch.object(focus, "detect_desktop", return_value="plasma-wayland"):
            with mock.patch.object(
                focus, "_adapter_plasma_wayland", return_value=plasma_win
            ) as plasma:
                with mock.patch.object(focus, "_adapter_hyprland") as hypr:
                    with mock.patch.object(focus, "_adapter_sway") as sway:
                        with mock.patch.object(focus, "_adapter_xdotool") as x11:
                            got = focus.get_active_window()
        self.assertEqual(got, plasma_win)
        plasma.assert_called_once()
        hypr.assert_not_called()
        sway.assert_not_called()
        x11.assert_not_called()

    def test_get_active_window_uses_only_hyprland_adapter(self) -> None:
        from ncc_assistant import focus

        hypr_win = {
            "class": "firefox",
            "title": "reddit",
            "source": "hyprland",
            "desktop": "hyprland",
        }
        with mock.patch.object(focus, "detect_desktop", return_value="hyprland"):
            with mock.patch.object(
                focus, "_adapter_hyprland", return_value=hypr_win
            ) as hypr:
                with mock.patch.object(focus, "_adapter_plasma_wayland") as plasma:
                    with mock.patch.object(focus, "_adapter_xdotool") as x11:
                        got = focus.get_active_window()
        self.assertEqual(got, hypr_win)
        hypr.assert_called_once()
        plasma.assert_not_called()
        x11.assert_not_called()

    def test_video_count_by_url(self) -> None:
        from ncc_assistant.focus import tick
        from ncc_assistant.paths import focus_state_file
        from ncc_assistant.preferences import set_doomscroll_max_videos, set_doomscroll_site_pack

        set_doomscroll_site_pack("youtube-shorts")
        set_doomscroll_max_videos(10)
        focus_state_file().parent.mkdir(parents=True, exist_ok=True)
        focus_state_file().write_text(
            json.dumps(
                {
                    "streak_sec": 30.0,
                    "video_count": 9,
                    "last_title": "https://www.youtube.com/shorts/aaa",
                    "last_tick": time.time() - 5,
                    "last_match": True,
                    "last_intervene": 0.0,
                    "snooze_until": 0.0,
                }
            )
            + "\n",
            encoding="utf-8",
        )
        win = {
            "class": "firefox",
            "title": "Same caption forever - YouTube — Mozilla Firefox",
            "url": "https://www.youtube.com/shorts/bbb",
            "source": "kwin",
        }
        with mock.patch(
            "ncc_assistant.presence.get_presence",
            return_value=mock.Mock(state="available"),
        ):
            with mock.patch(
                "ncc_assistant.notifications.notify_send", return_value=True
            ):
                result = tick(force_window=win)
        self.assertTrue(result.get("intervened"))
        self.assertEqual(result.get("reason"), "videos")

    def test_video_count_intervened(self) -> None:
        from ncc_assistant.focus import tick
        from ncc_assistant.paths import focus_state_file
        from ncc_assistant.preferences import set_doomscroll_max_videos, set_doomscroll_site_pack

        set_doomscroll_site_pack("youtube-shorts")
        set_doomscroll_max_videos(10)
        focus_state_file().parent.mkdir(parents=True, exist_ok=True)
        focus_state_file().write_text(
            json.dumps(
                {
                    "streak_sec": 30.0,
                    "video_count": 9,
                    "last_title": "Short A - YouTube",
                    "last_tick": time.time() - 5,
                    "last_match": True,
                    "last_intervene": 0.0,
                    "snooze_until": 0.0,
                }
            )
            + "\n",
            encoding="utf-8",
        )
        win = {"class": "firefox", "title": "Short B #Shorts - YouTube", "source": "test"}
        with mock.patch(
            "ncc_assistant.presence.get_presence",
            return_value=mock.Mock(state="available"),
        ):
            with mock.patch(
                "ncc_assistant.notifications.notify_send", return_value=True
            ):
                result = tick(force_window=win)
        self.assertTrue(result.get("intervened"))
        self.assertEqual(result.get("reason"), "videos")

    def test_match_firefox_reddit(self) -> None:
        from ncc_assistant.focus import is_doomscroll_window

        self.assertTrue(
            is_doomscroll_window(
                {"class": "firefox", "title": "reddit: the front page"}
            )
        )
        self.assertFalse(
            is_doomscroll_window(
                {"class": "firefox", "title": "NixOS Manual"}
            )
        )
        self.assertFalse(
            is_doomscroll_window(
                {"class": "code", "title": "reddit"}
            )
        )

    def test_listed_apps_mode(self) -> None:
        from ncc_assistant.focus import is_doomscroll_window
        from ncc_assistant.preferences import set_doomscroll_match_mode

        set_doomscroll_match_mode("listed-apps")
        self.assertTrue(
            is_doomscroll_window({"class": "firefox", "title": "about:blank"})
        )

    def test_tick_intervened(self) -> None:
        from ncc_assistant.focus import peek_pending_nudge, tick
        from ncc_assistant.paths import focus_state_file

        win = {"class": "firefox", "title": "YouTube - Home", "source": "test"}
        # Seed streak near threshold
        focus_state_file().parent.mkdir(parents=True, exist_ok=True)
        focus_state_file().write_text(
            json.dumps(
                {
                    "streak_sec": 4 * 60,
                    "last_tick": time.time() - 90,
                    "last_match": True,
                    "last_intervene": 0.0,
                    "snooze_until": 0.0,
                }
            )
            + "\n",
            encoding="utf-8",
        )
        with mock.patch(
            "ncc_assistant.presence.get_presence",
            return_value=mock.Mock(state="available"),
        ):
            with mock.patch(
                "ncc_assistant.notifications.notify_send", return_value=True
            ):
                result = tick(force_window=win)
        self.assertTrue(result.get("intervened"))
        self.assertIsNotNone(peek_pending_nudge())

    def test_snooze_blocks(self) -> None:
        from ncc_assistant.focus import snooze, tick

        snooze(30)
        win = {"class": "firefox", "title": "Reddit"}
        with mock.patch(
            "ncc_assistant.presence.get_presence",
            return_value=mock.Mock(state="available"),
        ):
            result = tick(force_window=win)
        self.assertFalse(result.get("intervened"))
        self.assertEqual(result.get("reason"), "snoozed")

    def test_intervene_action_prefs(self) -> None:
        from ncc_assistant.preferences import (
            get_doomscroll_block_input,
            get_doomscroll_follow_target,
            get_doomscroll_inject_chat,
            get_doomscroll_pause_media,
            set_doomscroll_block_input,
            set_doomscroll_follow_target,
            set_doomscroll_inject_chat,
            set_doomscroll_pause_media,
        )

        self.assertTrue(get_doomscroll_pause_media())
        self.assertTrue(get_doomscroll_follow_target())
        self.assertFalse(get_doomscroll_block_input())
        self.assertFalse(get_doomscroll_inject_chat())
        set_doomscroll_pause_media(False)
        set_doomscroll_follow_target(False)
        set_doomscroll_block_input(True)
        set_doomscroll_inject_chat(True)
        self.assertFalse(get_doomscroll_pause_media())
        self.assertFalse(get_doomscroll_follow_target())
        self.assertTrue(get_doomscroll_block_input())
        self.assertTrue(get_doomscroll_inject_chat())

    def test_site_tags_enums_drive_match_and_block(self) -> None:
        from ncc_assistant.focus import is_doomscroll_window
        from ncc_assistant.preferences import (
            get_doomscroll_block_domains,
            set_doomscroll_apps,
            set_doomscroll_site_tags,
        )

        set_doomscroll_apps(["brave"])
        set_doomscroll_site_tags(["youtube-shorts", "tiktok"])
        domains = get_doomscroll_block_domains()
        self.assertIn("youtube.com", domains)
        self.assertIn("googlevideo.com", domains)
        self.assertIn("tiktok.com", domains)
        self.assertTrue(
            is_doomscroll_window(
                {
                    "class": "brave-browser",
                    "title": "Home",
                    "url": "https://www.tiktok.com/@x",
                }
            )
        )
        self.assertTrue(
            is_doomscroll_window(
                {
                    "class": "brave-browser",
                    "title": "x",
                    "url": "https://www.youtube.com/shorts/abc",
                }
            )
        )
        self.assertFalse(
            is_doomscroll_window(
                {"class": "brave-browser", "title": "NixOS Manual", "url": ""}
            )
        )

    def test_lockout_applies_net_block(self) -> None:
        from ncc_assistant.focus import tick
        from ncc_assistant.paths import focus_state_file
        from ncc_assistant.preferences import (
            set_doomscroll_lockout_min,
            set_doomscroll_max_videos,
            set_doomscroll_site_tags,
        )

        set_doomscroll_site_tags(["youtube-shorts"])
        set_doomscroll_max_videos(10)
        set_doomscroll_lockout_min(10)
        focus_state_file().parent.mkdir(parents=True, exist_ok=True)
        focus_state_file().write_text(
            json.dumps(
                {
                    "streak_sec": 30.0,
                    "video_count": 9,
                    "last_title": "https://www.youtube.com/shorts/aaa",
                    "last_tick": time.time() - 5,
                    "last_match": True,
                    "last_intervene": 0.0,
                    "lockout_until": 0.0,
                    "snooze_until": 0.0,
                }
            )
            + "\n",
            encoding="utf-8",
        )
        win = {
            "class": "firefox",
            "title": "Short - YouTube",
            "url": "https://www.youtube.com/shorts/bbb",
            "source": "mpris",
        }
        with mock.patch(
            "ncc_assistant.presence.get_presence",
            return_value=mock.Mock(state="available"),
        ):
            with mock.patch(
                "ncc_assistant.notifications.notify_send", return_value=True
            ):
                with mock.patch(
                    "ncc_assistant.focus_netblock.apply_net_block",
                    return_value={"ok": True, "method": "nft", "minutes": 10},
                ) as net:
                    with mock.patch(
                        "ncc_assistant.focus_actions.apply_intervene_side_effects",
                        return_value={},
                    ):
                        with mock.patch(
                            "ncc_assistant.focus_actions.leave_feed_tab",
                            return_value={
                                "ok": True,
                                "method": "wtype",
                                "action": "about:blank",
                            },
                        ) as leave:
                            with mock.patch(
                                "ncc_assistant.focus_actions.follow_target_desktop",
                                return_value=True,
                            ):
                                result = tick(force_window=win)
        self.assertTrue(result.get("intervened"))
        net.assert_called()
        leave.assert_called()
        self.assertEqual(result.get("actions", {}).get("net_block", {}).get("ok"), True)
        self.assertEqual(
            result.get("actions", {}).get("left_feed", {}).get("action"), "about:blank"
        )

    def test_settings_ui_enums_only(self) -> None:
        gui = (ROOT / "ncc_assistant" / "gui_pages.py").read_text(encoding="utf-8")
        settings_ui = (
            ROOT
            / "ncc_assistant"
            / "plugins"
            / "doomscroll"
            / "settings_ui.py"
        ).read_text(encoding="utf-8")
        companion = (ROOT / "ncc_assistant" / "companion.py").read_text(
            encoding="utf-8"
        )
        self.assertIn("class PluginsPage", gui)
        self.assertIn("Feature plugins", gui)
        self.assertNotIn("4f · Doomscroll prevention", gui)
        self.assertIn("Doomscroll prevention", settings_ui)
        self.assertIn("Grant net-block privilege", settings_ui)
        self.assertIn("PANEL_PLUGINS", companion)
        self.assertIn("plugin_toggle", companion)
        self.assertIn("plugin_configure", companion)
        self.assertIn("tick_all", companion)
        self.assertIn("present_interrupt_dialog", companion)
        plugins_init = (ROOT / "ncc_assistant" / "plugins" / "__init__.py").read_text(
            encoding="utf-8"
        )
        self.assertIn("FeaturePlugin", plugins_init)
        self.assertIn("tick_all", plugins_init)

    def test_netblock_requires_privilege_grant(self) -> None:
        from ncc_assistant.focus_netblock import apply_net_block
        from ncc_assistant.preferences import (
            set_doomscroll_netblock_granted,
            set_doomscroll_site_tags,
        )

        set_doomscroll_site_tags(["youtube-shorts"])
        set_doomscroll_netblock_granted(False)
        result = apply_net_block(minutes=5)
        self.assertFalse(result.get("ok"))
        self.assertEqual(result.get("error"), "privilege_not_granted")

    def test_plugin_registry_lists_doomscroll(self) -> None:
        from ncc_assistant.plugins import get_plugin, list_plugins
        from ncc_assistant.preferences import set_doomscroll_enable

        ids = [p.id for p in list_plugins()]
        self.assertIn("doomscroll", ids)
        p = get_plugin("doomscroll")
        self.assertIsNotNone(p)
        assert p is not None
        set_doomscroll_enable(False)
        self.assertFalse(p.is_enabled())
        p.set_enabled(True)
        self.assertTrue(p.is_enabled())

    def test_pause_media_calls_mpris(self) -> None:
        from ncc_assistant import focus_actions

        tracks = [
            {
                "title": "x",
                "url": "https://www.youtube.com/shorts/a",
                "status": "Playing",
                "dest": "org.mpris.MediaPlayer2.firefox.instance_1",
            }
        ]
        with mock.patch(
            "ncc_assistant.focus._firefox_mpris_tracks", return_value=tracks
        ):
            with mock.patch("ncc_assistant.focus._run", return_value="") as run:
                with mock.patch("shutil.which", return_value="/bin/qdbus"):
                    ok = focus_actions.pause_browser_media()
        self.assertTrue(ok)
        self.assertTrue(
            any("Player.Pause" in " ".join(c.args[0]) for c in run.call_args_list)
        )


if __name__ == "__main__":
    unittest.main()
