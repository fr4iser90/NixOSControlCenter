#!/usr/bin/env python3
"""Tests for device_discover / device_detect (no Qt)."""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path

GUI = Path(__file__).resolve().parents[1] / "ui" / "gui"
sys.path.insert(0, str(GUI))

import device_detect  # noqa: E402
import device_discover as disc  # noqa: E402


class DeviceDiscoverTests(unittest.TestCase):
    def test_discover_from_repo_blueprints(self) -> None:
        bp = (
            Path(__file__).resolve().parents[1]
            / "scripts"
            / "setup"
            / "modes"
            / "host-blueprints"
        )
        targets = disc.discover_device_targets(bp)
        labels = {t.label: t.blueprint for t in targets}
        self.assertIn("Jetson Orin Nano", labels)
        self.assertEqual(labels["Jetson Orin Nano"], "fr4iser-jetson-orin")
        self.assertIn("Strix Halo", labels)
        self.assertEqual(labels["Strix Halo"], "fr4iser-strix-halo")
        # Non-device blueprints must not appear
        self.assertNotIn("fr4iser-home", {t.blueprint for t in targets})

    def test_match_strix_rules(self) -> None:
        bp = (
            Path(__file__).resolve().parents[1]
            / "scripts"
            / "setup"
            / "modes"
            / "host-blueprints"
        )
        targets = {t.label: t for t in disc.discover_device_targets(bp)}
        t = targets["Strix Halo"]
        self.assertTrue(
            disc.target_matches(
                t,
                machine="x86_64",
                lspci="Strix Halo [Radeon 8060S Graphics]",
                lscpu="",
                cpuinfo="",
                model="",
                compatible="",
                text_blob="",
            )
        )
        self.assertFalse(
            disc.target_matches(
                t,
                machine="x86_64",
                lspci="Intel Corporation",
                lscpu="",
                cpuinfo="",
                model="",
                compatible="",
                text_blob="",
            )
        )

    def test_match_orin_rules(self) -> None:
        bp = (
            Path(__file__).resolve().parents[1]
            / "scripts"
            / "setup"
            / "modes"
            / "host-blueprints"
        )
        t = next(x for x in disc.discover_device_targets(bp) if "Orin" in x.label)
        self.assertTrue(
            disc.target_matches(
                t,
                machine="aarch64",
                lspci="",
                lscpu="",
                cpuinfo="",
                model="NVIDIA Orin Nano Developer Kit",
                compatible="nvidia,tegra234",
                text_blob="",
            )
        )
        self.assertFalse(
            disc.target_matches(
                t,
                machine="x86_64",
                lspci="",
                lscpu="",
                cpuinfo="",
                model="NVIDIA Orin Nano Developer Kit",
                compatible="nvidia,tegra234",
                text_blob="orin",
            )
        )

    def test_add_blueprint_without_wiring(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            (d / "my-board").write_text(
                """
{
  deviceTarget = {
    enable = true;
    label = "My Board";
    description = "Test board";
    match = {
      arch = [ "x86_64" ];
      lspci = [ "UniqueChipXYZ" ];
    };
  };
  systemType = "server";
}
""",
                encoding="utf-8",
            )
            (d / "ignored-home").write_text(
                '{ systemType = "desktop"; }\n', encoding="utf-8"
            )
            targets = disc.discover_device_targets(d)
            self.assertEqual(len(targets), 1)
            self.assertEqual(targets[0].label, "My Board")
            self.assertTrue(
                disc.target_matches(
                    targets[0],
                    machine="x86_64",
                    lspci="UniqueChipXYZ Controller",
                    lscpu="",
                    cpuinfo="",
                    model="",
                    compatible="",
                    text_blob="",
                )
            )

    def test_force_env(self) -> None:
        bp = (
            Path(__file__).resolve().parents[1]
            / "scripts"
            / "setup"
            / "modes"
            / "host-blueprints"
        )
        os.environ["NCC_FORCE_DEVICE_TARGETS"] = "Strix Halo"
        try:
            matched = disc.match_device_targets(disc.discover_device_targets(bp))
            self.assertEqual([t.label for t in matched], ["Strix Halo"])
            self.assertEqual(
                device_detect.detect_matched_device_targets(["Strix Halo", "Jetson Orin Nano"]),
                ["Strix Halo"],
            )
        finally:
            del os.environ["NCC_FORCE_DEVICE_TARGETS"]


if __name__ == "__main__":
    unittest.main()
