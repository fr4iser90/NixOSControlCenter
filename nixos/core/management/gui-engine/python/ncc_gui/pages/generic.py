"""Generic domain page — DomainPage kit + catalog actions."""

from __future__ import annotations

from ncc_gui.catalog import DomainAction, DomainInfo
from ncc_gui.scaffold import DomainPage

_SKIP = frozenset({"tui", "gui", "manager"})


def _desktop_actions(info: DomainInfo) -> list[DomainAction]:
    out: list[DomainAction] = []
    for action in info.actions:
        if not action.args:
            continue
        if action.args[0] in _SKIP:
            continue
        out.append(action)
    return out


class GenericDomainPage(DomainPage):
    def __init__(self, info: DomainInfo, parent=None) -> None:
        super().__init__(
            info.label,
            info.description or f"Manage “{info.id}”.",
            parent=parent,
        )
        self.info = info
        actions = _desktop_actions(info)
        if actions:
            for i, action in enumerate(actions):
                self.add_action(
                    action.label,
                    lambda a=tuple(action.args), l=action.label: self._run(a, l),
                    primary=(i == 0),
                )
        else:
            from PySide6.QtWidgets import QLabel

            hint = QLabel(
                "No desktop controls for this area yet.\n\n"
                f"For scripting:  ncc {info.id} …"
            )
            hint.setObjectName("nccMuted")
            hint.setWordWrap(True)
            self.add_content_widget(hint)
            self._actions_box.setVisible(False)
            if self._activity_box is not None:
                self._activity_box.setVisible(False)

    def _run(self, args: tuple[str, ...], label: str) -> None:
        self.run_ncc(self.info.id, *args)
