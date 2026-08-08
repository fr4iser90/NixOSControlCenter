"""Reusable domain action page — built on DomainPage kit."""

from __future__ import annotations

from collections.abc import Sequence

from ncc_gui.scaffold import DomainPage


class DomainActionsPage(DomainPage):
    def __init__(
        self,
        domain: str,
        title: str,
        actions: Sequence[tuple[str, tuple[str, ...]]],
        *,
        subtitle: str = "",
        confirm_labels: Sequence[str] | None = None,
        follow_target: bool = False,
        parent=None,
    ) -> None:
        super().__init__(title, subtitle, parent=parent)
        self.domain = domain
        self._confirm = set(confirm_labels or [])
        self._follow_target = follow_target

        for i, (label, args) in enumerate(actions):
            self.add_action(
                label,
                lambda a=args, l=label: self._run(a, l),
                primary=(i == 0),
            )

    def _run(self, args: tuple[str, ...], label: str) -> None:
        need = label if label in self._confirm else None
        self.run_ncc(
            self.domain,
            *args,
            need_confirm=need,
            follow_target=self._follow_target,
        )
