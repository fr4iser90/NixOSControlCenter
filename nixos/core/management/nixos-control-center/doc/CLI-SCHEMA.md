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
| `ncc` | Root UI (TUI today; shared Qt shell later) |
| `ncc help [<domain>]` | Help |
| `ncc <domain>` | Domain home: **GUI** if the domain has one, else short help / TUI |
| `ncc <domain> <verb> …` | Action |

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
| `packages` | GUI (Qt/PySide6) | CLI verbs already good |
| `system` | GUI later / TUI now | children stay under `system` |
| `modules` | GUI/TUI | one canonical name |
| `network` | GUI/TUI | wifi lives under `network` (alias `wifi` OK) |
| `desktop` | GUI/TUI | fill when ready |
| `user` | GUI/TUI | fill when ready |
| `lock` | GUI/TUI | move discover/restore/fetch here |
| `vm` | GUI/TUI | simplify `test-<distro>-*` → verbs |
| `ai` | GUI | PySide6 reference implementation |
| `nixify` | help or GUI | |
| `chronicle` | help or GUI | migrate UI to PySide6 |
| `ssh` | GUI/TUI | unify client + server |
| `homelab` | GUI/TUI | re-register; fix broken registration |

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
| Desktop GUI | **Primary for desktop users** — Qt / PySide6; configure modules here |
| CLI | **Primary for scripting / automation** — always available |
| TUI | **Optional** — servers without a desktop, or terminal enthusiasts (`ncc <domain> tui`) |
| Domain default | If a domain has a GUI, `ncc <domain>` opens it (not the TUI) |
| Toolkit debt | Chronicle GTK → migrate to PySide6 |
| Data | Nix libraries shared by CLI + GUI — not JSON-CLI as the contract |

Do **not** put “Open TUI” / “Open GUI” as primary buttons inside the root shell — the shell already *is* the GUI. Filter launcher verbs (`tui`, `gui`, `manager`) out of GUI catalog actions.

**TUI packaging:** `(getModuleApi "tui-engine").isEnabled getModuleConfig` — reads `systemConfig` for `tui-engine` (move-safe). `enable = null` (default) → off when desktop is on, on when headless. Override in systemConfig, e.g. `core.management.tui-engine.enable = true;`.


### GUI catalog (no hardwired domain list)

The root shell (`ncc` / `ncc gui`) builds its sidebar from **`NCC_GUI_CATALOG`**, generated by cli-registry:

1. **Every top-level registered command** → enabled domain (label/description/actions from the registry).
2. Optional **`registerGuiDomain`** stubs → greyed entries when a module is disabled but should still appear.

Adding a module = register a top-level command. **Do not** edit `gui-engine` / `catalog.py` for new domains.

Optional rich page: ship `ncc_gui.pages.<domain_id>` with `create_page()`; otherwise a **generic** page is used (actions from child commands).

```nix
# Optional: show greyed stub when disabled
(cliRegistry.registerGuiDomain "homelab" {
  label = "Homelab";
  description = "Docker Swarm and stacks";
  enabled = cfg.enable or false;
})
```

---

## 6. Registry checklist (for `commands.nix`)

When adding or renaming a command:

- [ ] User-facing path is `ncc <domain> …` with domain ≤ 12 chars, no hyphen
- [ ] `name` + `parent` set so dispatcher resolves `ncc domain verb` (no bare colliding `list`/`status`)
- [ ] `domain` field matches the domain token
- [ ] `longHelp` / script usage use `ncc …` only (never `ncc-foo`)
- [ ] **No aliases**
- [ ] GUI: top-level manager auto-appears in root shell; optional `registerGuiDomain` if disabled stubs are wanted; optional `ncc_gui.pages.<id>` only for custom UX

---

## 7. Implementation order (schema rollout)

1. [x] This document — naming locked.
2. [x] Sweep help strings to `ncc …`.
3. [x] `packages`: Nix lib + PySide6 GUI; `ncc packages` → GUI.
4. [x] Fix `homelab` registration under `ncc homelab …`.
5. [x] Nest `lock` / `ssh` / `network wifi` (no aliases).
6. [x] Chronicle → PySide6; shared NCC Qt shell with embedded domain pages.
