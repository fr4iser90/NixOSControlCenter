"""Qt helpers: grant net-block privilege at setup time (not mid-interrupt)."""

from __future__ import annotations

from typing import Any

from PySide6.QtWidgets import QMessageBox, QWidget


def offer_netblock_grant(parent: QWidget | None = None, *, force: bool = False) -> dict[str, Any]:
    """
    Opt-in + smoke-test helper (auth-check). Polkit YES rule (system) makes
    apply/clear passwordless for active sessions — no mid-scroll password.
    """
    from ...focus_netblock import grant_netblock_privilege
    from ...preferences import (
        get_doomscroll_lockout_min,
        get_doomscroll_netblock_granted,
    )

    if not force and get_doomscroll_netblock_granted():
        return {"ok": True, "already": True}
    if not force and get_doomscroll_lockout_min() <= 0:
        return {"ok": True, "skipped": True, "reason": "lockout_off"}

    reply = QMessageBox.question(
        parent,
        "Net-block privilege",
        "Allow timed nft net-block on interrupt?\n\n"
        "This opts NCC in (preference). After system-update, Polkit allows "
        "ncc-focus-netblock without a password for your active session — "
        "you should not see Authentication Required mid-scroll.\n\n"
        "Cancel = interrupt still works; net-block stays off until granted.",
        QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        QMessageBox.StandardButton.Yes,
    )
    if reply != QMessageBox.StandardButton.Yes:
        return {"ok": False, "skipped": True, "reason": "declined"}

    result = grant_netblock_privilege()
    if result.get("ok"):
        QMessageBox.information(
            parent,
            "Net-block privilege",
            "Net-block enabled. Interrupts can sinkhole selected site domains "
            "without another password prompt (Polkit rule for active session).",
        )
    else:
        QMessageBox.warning(
            parent,
            "Net-block privilege",
            f"Grant failed: {result.get('error') or result.get('stderr') or 'unknown'}\n"
            f"{result.get('hint') or ''}",
        )
    return result
