# NCC GUI Design System (SSOT)

**This document is binding.** Domain pages (`ui/gui/page.py`), root shell, and
generic fallback must follow it. Do not invent a second layout per module.

Related code (the **kit** — use this, don’t reinvent layout):

- **Page kit:** `python/ncc_gui/scaffold.py` → `DomainPage` / `PageScaffold`
- Theme: `python/ncc_gui/theme.py` (`APP_STYLE`)
- Dialogs: `python/ncc_gui/dialogs.py`
- ANSI strip: `python/ncc_gui/ansi.py`
- Remote/`ncc`: `python/ncc_gui/remote.py` (also wrapped on `DomainPage`)
- Root shell: `python/ncc_gui/shell.py`
- Domain window: `python/ncc_gui/domain_gui.py`
- Icons: `assets/ncc-icon.{svg,png}` + `python/ncc_gui/branding.py`
- Pages live in **each module** (`ui/gui/page.py` + `registerGuiPage`) — never in `gui-engine/pages/` for domains

---

## 0. Kit API (gui-engine delivers this)

Every rich page should subclass or compose **`DomainPage`**:

```python
from ncc_gui.scaffold import DomainPage
from PySide6.QtWidgets import QComboBox, QCheckBox

class ExamplePage(DomainPage):
    def __init__(self, parent=None):
        super().__init__("Example", "One short end-user sentence.", parent=parent)
        form = self.add_form_block("Settings")
        self.mode = QComboBox()
        form.addRow("Mode", self.mode)
        self.add_actions_hint("Apply needs admin rights.")
        self.add_actions_widget(QCheckBox("Rebuild after apply"))
        self.add_action("Apply", self._apply, primary=True)
        self.add_action("Reload", self.reload)

    def reload(self):
        ...  # fill widgets — do not dump raw status into Activity

    def _apply(self):
        self.run_ncc_root(["example", "set", "..."], label="Apply", on_done=...)
```

| Method | Purpose |
|--------|---------|
| `add_block(title)` | Content `QGroupBox` |
| `add_form_block(title)` | Block + `QFormLayout` |
| `add_list_block(title)` | Block + `QListWidget` |
| `add_content_widget` / `add_content_layout` | Splitters, lists, custom |
| `add_actions_hint` / `add_actions_widget` | Text / checkboxes in Actions |
| `add_action(label, slot, primary=False)` | Bordered button in Actions |
| `log_append` / `log_write` / `log_clear` | Activity (ANSI stripped) |
| `run_ncc(*args, follow_target=, need_confirm=…)` | Sync `ncc` (+ Target) + log |
| `run_ncc_root(args, label=, on_done=)` | Async pkexec/sudo + stream log |
| `set_busy()` | Guard while root process runs |
| `activity_max_height=None` | Tall Activity (e.g. System update) |

Order is **fixed inside the kit**. Do not hand-roll a second vertical layout.

---

## 1. Two entry points — same page content

| Entry | Command | Chrome |
|-------|---------|--------|
| **Root Control Center** | `ncc` (with display) / root GUI | **Target bar** + **sidebar** (Core / Features) + content |
| **Domain window** | `ncc <domain> --gui` | **Standalone window**, title `ncc <domain>`, **same page widget** as in the shell |

Rules:

- The **page body** is identical in both modes (one `create_page()`).
- Root adds navigation + Target. Domain window does **not** duplicate the sidebar.
- Target bar is **only** on the root shell (fleet). Local-only domains (`hosts`, `ssh`) ignore Target for their actions; others follow `NCC_TARGET_HOST` when set from the bar.

```text
ncc                          ncc desktop --gui
┌─────────────────────┐      ┌──────────────────┐
│ Target              │      │ Desktop page     │
├──────┬──────────────┤      │ (same widget)    │
│ Nav  │ Domain page  │      └──────────────────┘
└──────┴──────────────┘
```

---

## 2. Mandatory page vertical order

Every domain page stacks **top → bottom** in this order. No reordering.

```text
┌─────────────────────────────────────────────┐
│ 1. HEADER                                   │
│    Title (#nccPageTitle)                    │
│    Subtitle — 1–2 sentences, end-user speak │
├─────────────────────────────────────────────┤
│ 2. CONTENT                                  │
│    One or more BLOCKS (QGroupBox)           │
│    Settings / Status / Lists / Forms        │
│    Human labels — NEVER raw key=value dump  │
├─────────────────────────────────────────────┤
│ 3. ACTIONS                                  │
│    Exactly one QGroupBox titled "Actions"   │
│    Primary + secondary buttons (bordered)   │
│    Confirms / rebuild checkboxes live HERE  │
├─────────────────────────────────────────────┤
│ 4. ACTIVITY (optional)                      │
│    QGroupBox "Activity" + #nccActivityLog   │
│    Empty until the user runs an action      │
│    Strip ANSI. Not a status dump on load.   │
└─────────────────────────────────────────────┘
```

### Forbidden

- Raw CLI / `key=value` / Nix dumps as the **main** content
- Actions floating above Settings with no frame, or Actions buried under a status log that looks like the product
- Pre-filling Activity with `ncc … status` on page load
- Cards inside cards, pill soup, emoji decoration, purple glow themes
- Putting domain-specific pages under `gui-engine`

---

## 3. Building blocks (what we use)

| Element | Qt | Role |
|---------|-----|------|
| **Block** | `QGroupBox` | Framed section with title (`Settings`, `Actions`, `Activity`, `Stacks`, …) |
| **Form row** | `QFormLayout` + `QLabel` / `QComboBox` / `QLineEdit` / `QCheckBox` | Editable or read-only fields with **human** labels |
| **Primary button** | `QPushButton` (default / first in Actions) | Apply, Save, Connect — needs confirm if destructive/rebuild |
| **Secondary button** | `QPushButton` | Reload, Refresh list, Cancel-adjacent |
| **List** | `QListWidget` | Pick one of many (hosts, VMs, stacks) |
| **Activity log** | `QTextEdit#nccActivityLog` | Command output only |
| **Dialogs** | `ncc_gui.dialogs` | `confirm` / `error` / `info` — never invent custom modal chrome |
| **Banner** | `QFrame#nccDisabledBanner` | Module off / not on target |

### Cards

- **Default: no free-floating cards.** A **Block** (`QGroupBox`) is the only framed container.
- Do not wrap every field in its own card.
- Lists sit inside a Block, not as naked widgets next to buttons.

### Buttons

- Always inside the **Actions** block (or a tight toolbar *inside* a Content block for list-row ops like Start/Stop next to a selection — then still framed by that block).
- Must look like buttons: **border + padding** (see theme). Plain text-looking actions = bug.
- Primary left, secondary right of it, then stretch.

---

## 4. Content patterns by page type

### A. Settings editor (Desktop, future User, …)

1. Header  
2. Block **Settings** — combos/toggles  
3. Block **Actions** — Apply (+ optional “Rebuild after apply”), Reload  
4. Activity — only after Apply/Reload commands  

Reload = refresh **widgets** from `ncc <domain> status` (parse into fields). Do **not** dump status text into Activity on load.

### B. Status + tools (Homelab, System report-ish)

1. Header  
2. Block **Status** — short human summary (labels, not raw dump)  
3. Block **…** (Stacks, Domains, …)  
4. Actions  
5. Activity for command output  

### C. List + detail (SSH, VM, Hosts, Packages)

1. Header  
2. Split or stacked: **List** block + **Detail/Actions** block  
3. Activity for long ops  

### D. Generic fallback (`GenericDomainPage`)

1. Header from catalog  
2. Actions from registry verbs  
3. Activity  

---

## 5. Theme

- Single stylesheet: `APP_STYLE` in `theme.py`. Pages call `self.setStyleSheet(APP_STYLE)`.
- Prefer **palette()** roles so Plasma light/dark works. Do not hardcode purple/cream AI themes.
- Object names to use:

| Object name | Use |
|-------------|-----|
| `#nccPageTitle` | H1 |
| `#nccPageSubtitle` / `#nccMuted` | Supporting text |
| `#nccActivityLog` | Log |
| `#nccNav` | Root sidebar only |
| `#nccShellRoot` | Root shell root |
| `#nccDisabledBanner` | Disabled state |

Buttons **must** have an explicit border in `APP_STYLE` so they don’t dissolve into the background on dark Plasma.

---

## 6. Icons & assets

| Asset | Path | Use |
|-------|------|-----|
| App icon PNG/SVG | `gui-engine/assets/ncc-icon.{png,svg}` | Window icon, sidebar brand, desktop entry `Icon=ncc` |
| Loader | `ncc_gui.branding.app_icon()` | All windows via `ensure_app` |
| Env override | `NCC_GUI_ICON` | Absolute path to icon file |

Domain pages: **no per-domain icons required** unless the module ships its own under `ui/gui/assets/` and documents it. Default = shared NCC icon only.

Desktop entry: `ncc.desktop`, exec `ncc`, icon name `ncc` (hicolor from gui-engine when GUI enabled).

---

## 7. Copy / language

- End-user wording: “Login screen”, “Dark theme”, “Apply” — not `display.manager`, `theme.dark`.
- Dangerous / rebuild: always `confirm()` with plain consequences (“rebuild”, “re-login”).
- Errors: `error()` + short Activity line; strip ANSI (`ncc_gui.ansi.strip_ansi`).

---

## 8. Checklist for a new `ui/gui/page.py`

- [ ] `DomainPage` kit; Header → Content → Actions → Activity; no raw dump as main UI
- [ ] Settings/status are human-readable (no raw dump as main UI)
- [ ] Actions via `add_action` / `add_actions_*`; Activity via `log_*` / `run_ncc*`
- [ ] Activity empty until an action runs
- [ ] `registerGuiPage` + optional `registerGuiDomain` with `group`
- [ ] Works in root shell **and** `ncc <domain> --gui`
- [ ] No imports of other modules’ pages; only `ncc_gui.*` kit

---

## 9. Root shell chrome (not part of domain pages)

1. **Target** bar (full width)  
2. Brand (icon + “NCC” / “Control Center”)  
3. Sidebar sections **Core** / **Features** (`registerGuiDomain.group`)  
4. Disabled domains: **hidden** (not grey stubs)  
5. Content = resolved page for selection  

---

*Last updated: GUI design lock — Desktop and all new pages must match §2.*
