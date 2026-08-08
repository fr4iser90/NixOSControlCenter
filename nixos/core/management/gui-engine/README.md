# NCC GUI Engine (Qt / PySide6)

**Complete kit** for NCC domain GUIs: layout scaffold, theme, dialogs, remote/`ncc`,
icons, root shell. Domain **content** stays in each module’s `ui/gui/page.py`.

## Kit (use this)

| Piece | Import / path |
|-------|----------------|
| Page scaffold | `from ncc_gui.scaffold import DomainPage` |
| Actions helper | `from ncc_gui.pages.base import DomainActionsPage` |
| Generic fallback | `ncc_gui.pages.generic.GenericDomainPage` |
| Theme | applied by `DomainPage` (`APP_STYLE`) |
| Dialogs | `ncc_gui.dialogs` |
| `ncc` helpers | `page.run_ncc` / `page.run_ncc_root` (`follow_target=True` for fleet) |
| Spec | [doc/GUI-DESIGN.md](./doc/GUI-DESIGN.md) |

```python
from ncc_gui.scaffold import DomainPage

class HomelabPage(DomainPage):
    def __init__(self, parent=None):
        super().__init__("Homelab", "Short end-user sentence.", parent=parent)
        form = self.add_form_block("Status")
        _, stacks = self.add_list_block("Stacks")
        self.add_action("Refresh", self.reload, primary=True)
```

### DomainPage API (short)

- Content: `add_block`, `add_form_block`, `add_list_block`, `add_content_widget`
- Actions: `add_action`, `add_actions_hint`, `add_actions_widget`
- Activity: `log_*`, `run_ncc(..., follow_target=)`, `run_ncc_root(...)`
- Layout order is fixed — do not hand-roll Header/Actions/Activity.
## Nix wiring

```nix
gui = getModuleApi "gui-engine";
cli = getModuleApi "cli-registry";
domainGui = gui.domainGui pkgs config;
(cli.registerGuiPage "homelab" ./ui/gui)
(cli.registerGuiDomain "homelab" {
  label = "Homelab";
  description = "…";
  enabled = cfg.enable or false;
  group = "features";
})
```

**Do not** put domain pages under `gui-engine/python/ncc_gui/pages/`.  
**Do not** hand-roll Header/Actions/Activity — `DomainPage` owns that order.

## Layout map

| Location | Responsibility |
|----------|----------------|
| `scaffold.DomainPage` | Header → Content → Actions → Activity |
| `shell` / Target / catalog | Root `ncc` chrome only |
| `<module>/ui/gui/page.py` | Domain fields + actions |
| `assets/ncc-icon.*` | App icon |
