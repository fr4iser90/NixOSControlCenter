# NCC CLI Schema (canonical)

**Status:** normative — new commands and renames must follow this.  
**Related:** [TODO.md](./TODO.md) (checkbox backlog), [gui-architecture.md](../gui-architecture.md) (Qt/PySide6), older notes in [ncc-command-architecture.md](../ncc-command-architecture.md) (historical; this file wins on conflicts).

User-facing form is always:

```text
ncc <domain> [<verb> [<noun> …]] [--flags]
```

Never show internal store binaries (`ncc-packages`, `ncc-config-layout`, …) in help, errors, or docs.

---

## 1. Shape

| Form | Meaning |
|------|---------|
| `ncc` | Root GUI shell (desktop) / TUI if no display |
| `ncc help [<domain>]` | Help |
| `ncc <domain>` | **CLI** (help or interactive manager) — never Qt by default |
| `ncc <domain> --gui` | Domain GUI |
| `ncc <domain> --tui` | Domain TUI (if enabled) |
| `ncc <domain> <verb> …` | CLI action |

Flat top-level verbs (`ncc discover`, `ncc ssh-status`) are **not allowed**. Nest under a domain.

### Common flags (shared vocabulary)

| Flag | Meaning |
|------|---------|
| `-y`, `--yes` | Non-interactive confirm / rebuild |
| `-n`, `--dry-run` | No writes / no rebuild |
| `--force` | Override safety checks |
| `-v`, `--verbose` | Extra logging |
| `--system` | System-wide target (vs user) |
| `--user <name>` | Explicit user target |
| `--no-build` | Skip rebuild prompt after config edits |

Do **not** standardize on `--json` CLI output. Structured data for GUIs/tools comes from **Nix libs** (and thin Python/Qt callers), not JSON flags as the primary contract.

---

## 2. Domain naming

### Rules (normative)

1. **Charset:** lowercase ASCII letters and digits only in the preferred form: `[a-z][a-z0-9]*`.
2. **Hyphen in domain names: no** for new domains.  
   Prefer nesting (`ncc ssh client …`) over compound domains (`ncc ssh-client …`).
3. **One word** that a user would say out loud: `packages`, `system`, `lock`, `vm`, `ai`.
4. **Max length: 12 characters** for the domain token.  
   If it does not fit, the name is wrong — shorten or nest (`homelab`, not `homelab-manager`).
5. **No `-manager`, `-client`, `-server`, `-status` suffixes** on domains. Those are roles or verbs, not domain names.
6. **`domain` registry field** equals the user-facing domain string (e.g. `ai`, not `specialized`).

### Allowed exception (hyphen)

Only for **legacy aliases** that already shipped (see §4). New public domains must be a single token without `-`.

### Good vs bad

| Good | Bad | Why |
|------|-----|-----|
| `packages` | `package-manager` | suffix noise; length |
| `system` | `system-manager` | same |
| `modules` | `module-manager` | alias at most |
| `ssh` | `ssh-client-manager` | nest client/server under `ssh` |
| `homelab` | `homelab-status` | status is a verb |
| `lock` | `discover` at top level | verb must sit under domain |
| `ai` | `ncc-assistant` / `assistant` as primary | keep short; binary may stay `ncc-assistant` internally |
| `chronicle` | — | 9 chars, OK |
| `nixify` | — | 6 chars, OK |

### Canonical domain list (target)

| Domain | Default (`ncc <domain>`) | Notes |
|--------|--------------------------|-------|
| `packages` | CLI help; `--gui` for Qt | |
| `system` | CLI help; `--gui` / `--tui` | children under `system` |
| `modules` | CLI help; `--gui` / `--tui` | |
| `network` | CLI help; `--gui` / `--tui` | wifi under `network` |
| `desktop` | CLI help; `--gui` / `--tui` | |
| `user` | CLI help; `--gui` / `--tui` | |
| `lock` | CLI help; `--gui` / `--tui` | |
| `vm` | CLI help; `--gui` / `--tui` | |
| `ai` | domain CLI / `--gui` | |
| `nixify` | help or CLI | |
| `chronicle` | help or CLI | |
| `ssh` | CLI (`client` = manager); `--gui` / `--tui` | unify client + server |
| `homelab` | CLI help; `--gui` | |
| `hosts` | CLI help; `--gui` | fleet targets; reuses SSH `~/.creds` |

---

## 3. Verbs and nouns

1. **Verbs:** lowercase, usually one word: `add`, `remove`, `list`, `update`, `build`, `status`, `scan`, …
2. **Hyphen in verbs: discouraged.** Prefer a second token (`test run`, `config layout`) over `test-run` / `config-layout` when registering new children.  
   Existing `config-layout` may keep a legacy alias until renamed.
3. **Nouns / targets** follow the verb: `ncc packages module add gaming`, `ncc vm test run nixos`.
4. **Do not** register bare global names that collide (`list`, `status`, `update` as top-level). Always `parent = "<domain>"`.

### Per-domain verb sketch (target)

```text
ncc packages add|remove|list …
ncc packages module list|available|add|remove|info …

ncc system build|update|report|allow-unfree|…
ncc system config layout detect|convert …
ncc system channel update|check …          # fold update-channels / check-release

ncc modules …                              # TUI/GUI; enable|disable later
ncc network wifi scan|list|status|connect|disconnect|forget
ncc lock discover|restore|fetch|restore-from-github …
ncc vm status|list
ncc vm test run <distro> …
ncc vm test reset <distro>
ncc ai …                                   # keep argparse tree; docs must say ncc ai
ncc ssh client list|add|edit|delete|connect|…
ncc ssh status|monitor|request|grant|approve|deny|…
ncc hosts list|show|use|add|remove …
ncc homelab status|init-swarm|list-stacks|minimize|…
ncc nixify …
ncc chronicle …
```

---

## 4. Aliases

**Policy: no aliases.** One canonical path only. Do not register legacy flat names (`ncc discover`, `ncc wifi`, `ncc ssh-status`, `ncc module-manager`, `ncc homelab-status`, …).

| Rule | Detail |
|------|--------|
| Canonical | Exactly one public path per action |
| Dispatcher | Commands with `parent` match **only** `parent-name` (`ncc lock discover` → `lock-discover`), never bare `discover` |
| Help | Only documents the canonical form |
| Internal binaries | May still be named `ncc-*` in the store; never shown to users |

Historical aliases (if any remain in old generations) are unsupported after rebuild.

---

## 5. UI policy (tied to schema)

| Layer | Choice |
|-------|--------|
| Desktop GUI | Qt / PySide6 — root `ncc`, or `ncc <domain> --gui` (gated by `gui-engine.enable`) |
| CLI | **Default for every domain** — scripting / interactive managers |
| TUI | Optional — `ncc <domain> --tui` when `tui-engine.enable` |
| Domain default | **`ncc <domain>` is never Qt** — use `--gui` |
| GUI toggle | `core.management.gui-engine.enable` — `null` = auto (on with desktop), `true`/`false` override |
| TUI toggle | `core.management.tui-engine.enable` — `null` = auto (off with desktop), `true`/`false` override |
| Toolkit debt | Chronicle GTK → migrate to PySide6 |
| Data | Nix libraries shared by CLI + GUI |

Do **not** register bare verbs `gui` / `tui` as primary actions (flags only). Filter legacy launcher names out of GUI catalog actions if they still exist.

**TUI packaging:** `(getModuleApi "tui-engine").isEnabled getModuleConfig` — reads `systemConfig` for `tui-engine` (move-safe). `enable = null` (default) → off when desktop is on, on when headless. Override in systemConfig, e.g. `core.management.tui-engine.enable = true;`.

### GUI catalog (no hardwired domain list)

The root shell (`ncc` / `ncc gui`) builds its sidebar from **`NCC_GUI_CATALOG`**, generated by cli-registry:

1. **Every top-level registered command** → enabled domain (label/description/actions from the registry).
2. Optional **`registerGuiDomain`** stubs → catalog when a module is disabled but should still appear for remote Target.
3. Optional **`registerGuiPage "<id>" ./ui/gui`** → rich Qt page from the **module** (`ui/gui/page.py` with `create_page()`). Never put domain pages inside `gui-engine`.

Without a registered page → **generic** page (actions from child commands).

```nix
(cliRegistry.registerGuiDomain "homelab" {
  label = "Homelab";
  description = "Docker Swarm and stacks";
  enabled = cfg.enable or false;
})
(cliRegistry.registerGuiPage "homelab" ./ui/gui)
```

Adding a module = register a top-level command (+ optional GUI page). **Do not** edit `gui-engine` for new domains.
---

## 6. Registry checklist (for `commands.nix`)

When adding or renaming a command:

- [ ] User-facing path is `ncc <domain> …` with domain ≤ 12 chars, no hyphen
- [ ] `name` + `parent` set so dispatcher resolves `ncc domain verb` (no bare colliding `list`/`status`)
- [ ] `domain` field matches the domain token
- [ ] `longHelp` / script usage use `ncc …` only (never `ncc-foo`)
- [ ] **No aliases**
- [ ] GUI: top-level manager auto-appears in root shell; optional `registerGuiDomain`; rich UX via `registerGuiPage` + `ui/gui/page.py` in the **module**

---

## 7. Implementation order (schema rollout)

1. [x] This document — naming locked.
2. [x] Sweep help strings to `ncc …`.
3. [x] `packages`: Nix lib + PySide6 GUI; `ncc packages` → GUI.
4. [x] Fix `homelab` registration under `ncc homelab …`.
5. [x] Nest `lock` / `ssh` / `network wifi` (no aliases).
6. [x] Chronicle → PySide6; shared NCC Qt shell with embedded domain pages.
