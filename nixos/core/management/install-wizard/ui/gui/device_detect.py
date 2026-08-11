"""Match live hardware against discovered device-targets (SSOT in blueprints)."""

from __future__ import annotations

from device_discover import discover_device_targets, match_device_targets


def detect_matched_device_targets(
    known: list[str] | None = None,
) -> list[str]:
    """
    Return UI labels for device targets that match this machine.

    `known` filters to labels already in the UI list (usually all discovered).
    Detection rules come from each blueprint's deviceTarget.match — not hardcoded here.
    """
    targets = discover_device_targets()
    if known is not None:
        known_set = set(known)
        targets = [t for t in targets if t.label in known_set]
    matched = match_device_targets(targets)
    order = {t.label: i for i, t in enumerate(targets)}
    labels = sorted({t.label for t in matched}, key=lambda n: order.get(n, 999))
    return labels
