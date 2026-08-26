"""Remote sudo argv must not use sudo -p with empty prompt (consumes next arg)."""

from __future__ import annotations

from ncc_gui.push_tree import _run_remote_sudo_argv


def test_remote_sudo_argv_with_password_no_prompt_flag() -> None:
  cmd = ["nixos-rebuild", "switch", "--flake", "/etc/nixos#jetson-orin"]
  seen: list[list[str]] = []

  def fake_run(argv, **kwargs):  # type: ignore[no-untyped-def]
    seen.append(list(argv))
    class P:
      returncode = 0
      stdout = "ok"
      stderr = ""
    return P()

  import subprocess

  orig = subprocess.run
  subprocess.run = fake_run  # type: ignore[assignment]
  try:
    ok, _ = _run_remote_sudo_argv("u@host", cmd, sudo_password="secret")
  finally:
    subprocess.run = orig  # type: ignore[assignment]

  assert ok
  argv = seen[0]
  assert "-p" not in argv
  assert argv == [
    "ssh",
    "-o",
    "BatchMode=yes",
    "-o",
    "ConnectTimeout=8",
    "u@host",
    "--",
    "sudo",
    "-S",
    "nixos-rebuild",
    "switch",
    "--flake",
    "/etc/nixos#jetson-orin",
  ]
