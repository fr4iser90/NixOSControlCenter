# NCC GUI Design System (SSOT)

**This document is binding.** Domain pages (`ui/gui/page.py`), root shell, and
generic fallback must follow it. Do not invent a second layout per module.

Related code (the **kit** — use this, don’t reinvent layout):

- **Page kit:** `python/ncc_gui/scaffold.py` → `DomainPage` / `PageScaffold`
- **Commit bar:** `python/ncc_gui/commit_bar.py` → `CommitController` / `PendingChange` (on every `DomainPage`)
- Theme: `python/ncc_gui/theme.py` (`APP_STYLE`)
- Dialogs: `python/ncc_gui/dialogs.py`
- ANSI strip: `python/ncc_gui/ansi.py`
- Remote/`ncc`: `python/ncc_gui/remote.py` (also wrapped on `DomainPage`)
- Root shell: `python/ncc_gui/shell.py`
- Domain window: `python/ncc_gui/domain_gui.py`
- Icons: `assets/ncc-icon.{svg,png}` + `python/ncc_gui/branding.py`
- Page stub: `doc/PAGE-TEMPLATE.md`
- Pages live in **each module** (`ui/gui/page.py` + `registerGuiPage`) — never in `gui-engine/pages/` for domains

---

## 0. Kit API (gui-engine delivers this)

Every rich page should subclass or compose **`DomainPage`**:

```python
from ncc_gui.commit_bar import PendingChange
from ncc_gui.scaffold import DomainPage
from PySide6.QtWidgets import QComboBox

class ExamplePage(DomainPage):
    def __init__(self, parent=None):
        super().__init__("Example", "One short end-user sentence.", parent=parent)
        form = self.add_form_block("Settings")
        self.mode = QComboBox()
        form.addRow("Mode", self.mode)
        self.add_action("Reload", self.reload)
        assert self.commit is not None
        self.commit.set_flush_handler(self._flush)

    def reload(self):
        ...  # fill widgets — do not dump raw status into Activity

    def _on_mode_changed(self):
        # Stage — do not write config here
        self.commit.stage(PendingChange(
            summary=f"set mode {self.mode.currentText()}",
            argv=["example", "set", self.mode.currentText(), "--no-build"],
            elevated=True,
        ))

    def _flush(self, changes):
        # Write all pending; then tell the kit
        def done(code):
            self.commit.notify_apply_finished(code == 0, changes[0].summary)
            if code == 0:
                self.reload()
        self.run_ncc_root(changes[0].argv, label="Apply", on_done=done)
```

| Method | Purpose |
|--------|---------|
| `add_block(title)` | Content `QGroupBox` |
| `add_form_block(title)` | Block + `QFormLayout` |
| `add_list_block(title)` | Block + `QListWidget` |
| `add_content_widget` / `add_content_layout` | Splitters, lists, custom |
| `add_actions_hint` / `add_actions_widget` | Text / checkboxes in Actions |
| `add_action(label, slot, primary=False)` | Domain button (left of CommitBar) |
| `self.commit` | CommitBar: Undo / Save / Apply (§2.1) |
| `log_append` / `log_write` / `log_clear` | Activity (ANSI stripped) |
| `run_ncc(*args, follow_target=, need_confirm=…)` | Sync `ncc` (+ Target) + log |
| `run_ncc_async(args, label=, on_done=, env=)` | Async **as current user** (CLI may self-elevate via `ncc-priv-run`) |
| `run_ncc_root(args, label=, on_done=)` | Async **elevated** `ncc` — see §10 elevation order |
| `set_busy()` | Guard while a process runs |
| `activity_max_height=None` | Tall Activity (e.g. System update) |
| `commit_bar=False` | Rare opt-out (read-only tools) |

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
The footer stays **pinned to the bottom** of the page (app-like), not above Activity.

```text
┌─────────────────────────────────────────────┐
│ 1. HEADER                                   │
│    Title (#nccPageTitle)                    │
│    Subtitle — 1–2 sentences, end-user speak │
├─────────────────────────────────────────────┤
│ 2. CONTENT (stretch)                        │
│    One or more BLOCKS (QGroupBox)           │
│    Settings / Status / Lists / Forms        │
│    Human labels — NEVER raw key=value dump  │
├─────────────────────────────────────────────┤
│ 3. ACTIVITY (optional)                      │
│    QGroupBox "Activity" + #nccActivityLog   │
│    Empty until the user runs an action      │
│    Strip ANSI. Not a status dump on load.   │
├─────────────────────────────────────────────┤
│ 4. FOOTER / ACTIONS (pinned bottom)         │
│    QGroupBox "Actions" (#nccPageFooter)     │
│    Left: domain buttons (Add, Refresh, …)   │
│    Right: CommitBar — status · Undo · Save · Apply │
└─────────────────────────────────────────────┘
```

### 2.1 Commit bar (binding — every page)

**Default for config mutations:** draft in the UI first, write only on Apply.
Implemented in `ncc_gui.commit_bar`, attached by `DomainPage` as `self.commit`.

```text
Browse / change UI  →  stage (Add, Create…, toggles, …)
                    →  appears in the page UI as draft (list row / field)
                    →  Save (draft)  ·  Undo
                    →  Apply (≥1 pending)  →  write config (--no-build)
                    →  modal “Build required — Rebuild && switch?”
                         + Don’t show again
```

| Control | When enabled | Role |
|---------|--------------|------|
| **Undo** | pending or saved draft | Restore last save, or drop last staged item |
| **Save** | pending and not yet saved | Checkpoint draft (does **not** write disk) |
| **Apply** | ≥1 pending | Flush via domain `set_flush_handler` → disk |

#### Draft-first (default — nail this)

Anything that changes **Nix/NCC configuration** (users, packages, desktop,
network, modules, hosts records, …) must:

1. Open modal / collect input if needed (Create user, Add package, …).
2. **Stage** into `self.commit` **and** show the result in the page UI
   (e.g. new user row marked draft / “pending”, toggled set with pending mark).
3. **Not** call `ncc … create/add/set` and **not** rebuild until **Apply**.
4. On Apply: write with `--no-build`, then the shared rebuild modal.

The user must never feel that Create/Add already “built the system”. Create
only means “add to the draft list”.

Migrated: Packages; Users; Desktop; Module Manager; SSH Client; Hosts.  
New domain: **Hardware** (`core/base/hardware`) — inventory + autoDetect badge/toggle.  
(SSH/Hosts: `notify_apply_finished(..., offer_rebuild=False)` — no Nix rebuild.)

#### Immediate actions (small allowlist — exceptions)

These may run **now** (confirm + Activity), without CommitBar staging.
They are **not** config drafts — the verb *is* the effect:

| Allowed immediate | Examples | Why |
|-------------------|----------|-----|
| **System lifecycle** | System update, rebuild/switch/boot/test, channel sync | The page’s job *is* to build/sync |
| **Runtime control** | VM start/stop, stack up/down, service restart | Live process, not config draft |
| **Read-only / refresh** | Reload lists, status, report | No mutation |
| **Session / target** | Connect SSH, change Target host | Chrome / connection, not module config |

If unsure: **stage**. New exception = document it here first (do not invent
silently on a page).

`commit_bar=False` only for pure read-only tool pages. System Manager keeps
the CommitBar visible but unused for update/rebuild buttons (those stay
immediate on the left).

#### Rules (short)

- Domain config actions **stage**; they must **not** write config immediately.
- Writes use `--no-build`. Rebuild is **only** via the post-Apply modal (or rare manual “Rebuild…”).
- Do **not** invent per-page “Rebuild after changes” checkboxes.
- After Apply + successful flush, call `commit.notify_apply_finished(ok, summary)`.
  Use `offer_rebuild=False` for non-Nix config (SSH client list, etc.).

### Forbidden

- Raw CLI / `key=value` / Nix dumps as the **main** content
- Actions floating above Settings with no frame, or Actions buried under a status log that looks like the product
- Pre-filling Activity with `ncc … status` on page load
- Cards inside cards, pill soup, emoji decoration, purple glow themes
- Putting domain-specific pages under `gui-engine`
- Immediate config writes from Create/Add/Remove/Edit/toggles (bypass CommitBar)
- Per-page rebuild checkboxes instead of the shared rebuild modal
- Create/Add that already runs `ncc …` + rebuild before Apply
- Undocumented “exception” immediate config writes

---

## 3. Building blocks (what we use)

| Element | Qt | Role |
|---------|-----|------|
| **Block** | `QGroupBox` | Framed section with title (`Settings`, `Actions`, `Activity`, `Stacks`, …) |
| **Form row** | `QFormLayout` + `QLabel` / `QComboBox` / `QLineEdit` / `QCheckBox` | Editable or read-only fields with **human** labels |
| **Primary button** | `QPushButton#nccPrimaryButton` | CommitBar **Apply** (config); or allowlisted immediate (e.g. System update) |
| **Secondary button** | `QPushButton` | Create… / Refresh / domain ops that **stage**, or Undo/Save |
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
- Domain buttons left, stretch, then **CommitBar** (Undo / Save / Apply). Apply is `#nccPrimaryButton`.

---

## 4. Content patterns by page type

### A. Settings editor (Desktop, future User, …)

1. Header  
2. Block **Settings** — combos/toggles (stage into `self.commit` on change)  
3. Activity — only after Apply/Reload commands  
4. Footer **Actions** — Reload (left) + CommitBar Undo/Save/Apply (right)  

Reload = refresh **widgets** from `ncc <domain> status` (parse into fields). Do **not** dump status text into Activity on load.

### B. Status + tools (Homelab, System report-ish)

1. Header  
2. Block **Status** — short human summary (labels, not raw dump)  
3. Block **…** (Stacks, Domains, …)  
4. Actions  
5. Activity for command output  

### C. List + CRUD (Users, SSH servers, …) / dual-scope Packages

1. Header  
2. Block **List** — live rows + **draft/pending** rows from staged Create/Edit/Delete  
3. Activity for command output (after Apply / refresh — not on Create click)  
4. Footer Actions — **Create…** / **Edit…** / **Delete…** / Refresh (left) + CommitBar (right)

**Create and Edit use the same modal shape** (one dialog class, `mode=create|edit`).  
Do **not** mix: Create in a dialog + Edit as inline form on the page.

| Field | Create | Edit |
|-------|--------|------|
| Identity (username, host, …) | editable | read-only |
| Password (if any) | optional / required per domain | optional (“leave empty to keep”) |
| Other settings | editable | editable |

**Draft-first CRUD (binding):**

| User click | What happens |
|------------|----------------|
| Create… | Modal → OK → **pending row in list** + `commit.stage` — no `ncc` yet |
| Edit… | Modal → OK → row shows pending edits + stage — no write yet |
| Delete… | Row marked pending-delete (or confirm → stage) — no delete yet |
| Apply | Flush all pending `ncc … --no-build` → rebuild modal |

Do **not**: Create → immediate `ncc user create` (+ rebuild checkbox). That pattern is retired.

**Packages** (special dual-scope page): tabs **My packages** | **Recipes && sets** | **System packages** (admins).  
Multi-select by marking rows (`MultiSelection` — click toggles; no checkboxes). Batch Add/Remove **stages** into CommitBar; Apply writes.  
**System packages** lists explicit `systemPackages` **and** packages from active sets (source labeled). Removing a set-sourced row disables that set. See `PERMISSIONS.md`.

Prefer `run_ncc_async` when the CLI self-elevates (`ncc-priv-run`); use `run_ncc_root` only when the GUI must elevate a plain `ncc` that does not.

### D. Immediate tool pages (System update, VM runtime, …)

Same vertical layout, but primary buttons are **allowlisted immediate** actions
(§2.1). CommitBar stays in the **page footer** (below Activity), bottom-right (`commit_bar=False` only for pure read-only tools).
Confirm destructive/build actions; stream output into Activity.

### E. Generic fallback (`GenericDomainPage`)

1. Header from catalog  
2. Actions from registry verbs (prefer staging config verbs; immediate only if allowlisted)  
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
- **Never** mention `pkexec`, `sudo`, or store paths in UI copy. Say “administrator rights” / “you may be asked to confirm” if needed.

---

## 8. Checklist for a new `ui/gui/page.py`

- [ ] `DomainPage` kit; Header → Content → Activity → Footer Actions; no raw dump as main UI
- [ ] Settings/status are human-readable (no raw dump as main UI)
- [ ] Config writes draft-first: UI shows pending + CommitBar (`stage` → Apply → `notify_apply_finished`)
- [ ] No Create/Add that already runs `ncc` before Apply; no ad-hoc rebuild checkbox
- [ ] Immediate actions only if on §2.1 allowlist (else document new exception there first)
- [ ] Actions via `add_action` / `add_actions_*`; Activity via `log_*` / `run_ncc*`
- [ ] Activity empty until an action runs (Apply / allowed immediate / Refresh)
- [ ] List+CRUD: Create/Edit same modal + pending rows (§4.C) if applicable
- [ ] Elevation via kit (§10); no pkexec-first; no pkexec in copy
- [ ] `registerGuiPage` + optional `registerGuiDomain` with `group`
- [ ] Works in root shell **and** `ncc <domain> --gui`
- [ ] No imports of other modules’ pages; only `ncc_gui.*` kit
- [ ] Started from `doc/PAGE-TEMPLATE.md` stub when greenfield

---

## 9. Root shell chrome (not part of domain pages)

1. **Target** bar (full width)  
2. Brand (icon + “NCC” / “Control Center”)  
3. Sidebar sections **Core** / **Features** (`registerGuiDomain.group`)  
4. Disabled domains: **hidden** (not grey stubs)  
5. Content = resolved page for selection  

---

## 10. Elevation (binding — no password spam for NOPASSWD admins)

Admins with passwordless sudo must **not** get a polkit/password dialog for every click.

### `run_ncc_root` order (kit)

1. Already root → run `ncc`  
2. `sudo -n true` succeeds → `sudo -n ncc …`  
3. else `pkexec ncc …`  
4. else interactive `sudo ncc …`  

### `run_ncc_async`

Run `ncc` as the logged-in user. Prefer this when the CLI already elevates via **`ncc-priv-run`** (same sudo-n-first order). Used for Users account CRUD.

### Forbidden

- Preferring `pkexec` before `sudo -n` in new code  
- Hardcoding `pkexec` / `sudo` strings in page subtitles or action hints  
- Double elevation (GUI `pkexec` wrapping a command that itself calls `pkexec`) when `run_ncc_async` + `ncc-priv-run` is enough  

---

## 11. Consistency checklist (audit before merge)

- [ ] Page uses `DomainPage`; vertical order §2  
- [ ] Create/Edit both modals **or** both inline — never mixed (§4.C)  
- [ ] Elevated actions use kit helpers with §10 order  
- [ ] No `pkexec`/`sudo` in user-visible strings  
- [ ] Guest/role gating: hide actions, don’t only fail after click  
- [ ] At least one `admin` / `restricted-admin` remains (Users helper + Nix assertion)  
- [ ] After `nixos-rebuild switch`, GUI reloads via generation watcher (no manual restart required)

---

*Last updated: page footer order Header → Content → Activity → Actions (CommitBar bottom-right).*
