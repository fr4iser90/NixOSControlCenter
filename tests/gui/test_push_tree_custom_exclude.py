"""Remote install must never stage or apply Host custom/ on Target."""

from __future__ import annotations

from ncc_gui.push_tree import _APPLY_SH, _RSYNC_PUSH_EXCLUDES


def test_rsync_push_excludes_custom() -> None:
    assert "custom" in _RSYNC_PUSH_EXCLUDES


def test_apply_script_never_seeds_custom() -> None:
    assert "Seeding custom" not in _APPLY_SH
    assert "$SRC/custom" not in _APPLY_SH
    assert "cp -a \"$SRC/custom\"" not in _APPLY_SH
