# Domain GUI page template

Copy into `nixos/.../<module>/ui/gui/page.py`. Binding rules:
`gui-engine/doc/GUI-DESIGN.md`.

```python
"""<Domain> — short end-user description."""

from __future__ import annotations

from ncc_gui.commit_bar import PendingChange
from ncc_gui.scaffold import DomainPage


class ExamplePage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Example",
            "One or two sentences for the end user.",
            parent=parent,
        )
        form = self.add_form_block("Settings")
        # form.addRow("…", widget)

        self.add_action("Refresh", self.reload)
        # Domain ops stage changes — do not write config here.
        # self.add_action("Add…", self._stage_add)

        assert self.commit is not None
        self.commit.set_flush_handler(self._flush)
        self.reload()

    def reload(self) -> None:
        """Fill widgets from status/CLI. Do not dump raw status into Activity."""
        ...

    def _stage_example(self) -> None:
        assert self.commit is not None
        self.commit.stage(
            PendingChange(
                summary="example set …",
                argv=["example", "set", "...", "--no-build"],
                elevated=True,
            )
        )

    def _flush(self, changes: list[PendingChange]) -> None:
        """Write pending changes; then notify the CommitBar."""
        assert self.commit is not None
        if not changes:
            return
        summary = "; ".join(c.summary for c in changes)
        # Simple case: one elevated write. For many, queue like Packages.
        ch = changes[0]

        def done(code: int) -> None:
            self.commit.notify_apply_finished(code == 0, summary)
            if code == 0:
                self.reload()

        if ch.elevated:
            self.run_ncc_root(ch.argv, label=ch.summary, on_done=done)
        else:
            self.run_ncc_async(ch.argv, label=ch.summary, on_done=done)


def create_page() -> ExamplePage:
    return ExamplePage()


Page = ExamplePage
```

Flow: **UI draft first → stage → Save / Undo → Apply → rebuild modal** (kit).

- Config CRUD (users, packages, …): Create/Add only adds a **pending** row;
  `ncc` runs on Apply. See GUI-DESIGN §2.1 / §4.C.
- Immediate only if allowlisted (system update, VM start/stop, refresh, …).
- Never invent a second Apply/rebuild UX or “Rebuild after changes” checkbox.
