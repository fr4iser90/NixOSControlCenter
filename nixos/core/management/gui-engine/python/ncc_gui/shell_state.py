"""Chrome state for the multi-domain shell (catalog + current document id).

Process lifecycle (soft/hard) lives in ``ncc_gui.reload``.
Target session state lives in ``ncc_gui.target_session``.
This module is only the **catalog slice** the shell projects into the sidebar.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from ncc_gui.catalog import DomainInfo, load_domains

# Interactive documents kept when navigating away (still dropped on soft recreate
# of that domain, or when force-clearing after generation if mounted).
STICKY_DOMAIN_IDS = frozenset({"ai", "ssh"})


@dataclass
class ShellChromeState:
    """Sidebar catalog + which domain document is (or should be) mounted."""

    domains: list[DomainInfo] = field(default_factory=list)
    current_domain_id: str | None = None

    def refresh_catalog(self) -> bool:
        """Reload ``NCC_GUI_CATALOG``. False if empty/unavailable."""
        new = load_domains()
        if not new:
            return False
        self.domains = list(new)
        return True

    def info(self, domain_id: str) -> DomainInfo | None:
        for d in self.domains:
            if d.id == domain_id:
                return d
        return None

    def enabled_map(self) -> dict[str, bool]:
        return {d.id: d.enabled for d in self.domains}
