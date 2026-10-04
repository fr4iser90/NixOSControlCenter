# GUI Engine — Usage

Qt / PySide6 kit for NCC domain pages. Domain **content** lives in each module’s `ui/gui/page.py`; this module owns the shared scaffold, theme, dialogs, and shell.

## Quick start

```python
from ncc_gui.scaffold import DomainPage

class ExamplePage(DomainPage):
    def __init__(self, parent=None):
        super().__init__("Example", "Short end-user sentence.", parent=parent)
```

## Docs

| Doc | Topic |
|-----|--------|
| [gui-design.md](./gui-design.md) | Layout / chrome / document model |
| [page-template.md](./page-template.md) | Copy-paste page skeleton |
| [performance.md](./performance.md) | Cache / hot paths |

See also module [README.md](../README.md).
