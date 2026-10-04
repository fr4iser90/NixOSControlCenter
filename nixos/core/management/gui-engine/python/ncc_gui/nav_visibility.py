"""Pure sidebar visibility rules (GUI-DESIGN §9) — no Qt, no domain-id hardcodes.

Used by shell chrome and unit-tested under tests/gui/.
"""

from __future__ import annotations


def domain_nav_visible(
    *,
    always_visible: bool,
    group: str,
    catalog_on: bool,
    active: bool,
    hide_inactive_features: bool,
    allow: frozenset[str] | None,
    domain_id: str,
    local_only: frozenset[str],
) -> bool:
    """Return whether ``domain_id`` should appear in the sidebar.

    Rules:
    * ``local_only`` domains stay listed (still respect caller for gate).
    * When ``allow`` is set (remote gate), only allowlisted + local_only.
    * ``always_visible``: stay listed when Off (core managers).
    * else core: listed only when catalog enabled (conditional core).
    * features: all listed unless Settings → hide inactive features.
    """
    if domain_id in local_only:
        return True
    if allow is not None:
        return domain_id in allow
    if always_visible:
        return True
    if group == "core":
        return catalog_on
    if hide_inactive_features:
        return active
    return True
