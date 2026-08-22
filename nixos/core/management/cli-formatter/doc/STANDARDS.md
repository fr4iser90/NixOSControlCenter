# CLI Formatter — Standards (SSOT)

**Source of truth** for how every NCC CLI surface must look and talk.
Module `CLI.md` files only summarize *their* commands against this doc.

Related:
- [COPY.md](./COPY.md) — GUI vs CLI vs `--verbose` wording
- [API.md](./API.md) — function reference (keep in sync with `api.nix`)
- [USAGE.md](./USAGE.md) — examples

---

## 1. Law

```nix
ui = getModuleApi "cli-formatter";
# NEVER: config.core.management.cli-formatter
# NEVER: hand-rolled colors / echo -e / \\033
```

| Surface | Tone |
|---------|------|
| **GUI** | Plain language. No store paths / raw exceptions. Optional Details. |
| **CLI normal** | Short + clear. One path OK. No JSON dumps. |
| **CLI `-v` / `--verbose`** | Diffs, rc, long paths, JSON, layout/debug. |

---

## 2. What `cli-formatter` offers today (`api.nix`)

Access: `ui = getModuleApi "cli-formatter";`

| Area | API | Use for |
|------|-----|---------|
| Status lines | `ui.messages.{success,error,warning,info,loading,detailLevel}` | Default user-facing lines |
| Badges | `ui.badges.{success,error,warning,info,debug}` | Check results (`[ OK ]` / `[ERROR]`) |
| Structure | `ui.text.{header,subHeader,section,subsection,paragraph,keyValue,separator,highlight,codeBlock,…}` | Phase titles, KV |
| Tables | `ui.tables.keyValue` | Labeled facts (paths, counts) |
| Lists | `ui.lists.*` | Bullet / numbered lists |
| Boxes | `ui.boxes.*` | Framed summaries (sparingly) |
| Progress | `ui.progress.*` | Long ops with known total |
| Prompts | `ui.prompts.*` | Y/n, input |
| Spinners | `ui.spinners.*` | Indeterminate wait |
| Select | `ui.fzf.*` / `ui.menus.*` | Choose from many items |
| TUI | `ui.tui.*` | Full TUI (prefer tui-engine for big UIs) |
| Colors | `ui.colors` | **Internal only** — do not invent new palettes in scripts |

### Gaps to add (planned helpers — not yet in API)

| Helper | Why |
|--------|-----|
| `ui.flow.dryRunBanner` | Same “read-only / no writes” block everywhere |
| `ui.flow.step n total title` | `Step 2/5 — Backup` |
| `ui.flow.confirmYesNo msg` | One confirm pattern (`[Y/n]`) |
| `ui.flow.verboseGate shell` | Wrap `-v` detail without copy-paste `if` |
| `ui.flow.copyableError log rc` | Build-fail “COPYABLE ERROR” block |
| `ui.flow.nextHint cmd` | “Next: sudo ncc …” |

Until helpers land: **copy the patterns** from `system-manager` / `COPY.md`.

---

## 3. Command UX skeleton (every `ncc …` command)

**Mandatory** for user-facing scripts (update, migrate, config-check, packages, …):

```
1. header          ui.text.header "…"
2. dry-run banner  ui.messages.info "Preview only — nothing will be written…"   # if --dry-run
3. loading         ui.messages.loading "…"
4. facts           ui.tables.keyValue / short info  (−v for more)
5. work            …
6. result          success | warning | error
7. next            one clear next command (info)   # always on success / actionable failure
```

**Nested calls** (e.g. `system update` → `ncc-config-check` → `ncc-module-migrate`):
set `NCC_CLI_NESTED=1` so children **skip** their own header / dry banner / next
(parent owns the skeleton). Children still use `ui.messages` for work + result lines.

**Forbidden in normal mode:** raw `Layout: monolith`, full jq dumps, store paths, stack traces.
**Allowed in `-v`:** all of the above.

**Dry-run:** never write `/etc/nixos` (or other live roots). Skip dangerous prompts. Skip sudo when `--dry-run` (cli-registry already does this). Needs **read** access to `/etc/nixos`; if unreadable, say so and hint `sudo -n true` / fix perms — do not claim “no configuration”.

---

## 4. How `ncc system update` MUST look

**Voice:** default = short **checklist** (`[ OK ]` / `[WARN]` / `[ERROR]`).  
`-v` = same checklist **plus** every copy/preserve line, paths, JSON, and full `nixos-rebuild`/activation noise.

**One** `===` header for the whole run. No mid-flow `=== Build ===`, no `---` phases, no activation System Report (`ncc system report`).

### Default (what users should see)

```text
WARNING: …                         # registry; skipped with --yes / -y / dangerousIgnore / NCC_ASSUME_YES
Do you want to continue? (yes/no): y

=== NixOS System Update ===
[ OK ] Config
[ OK ] Migrations
Source: local — /home/…/NixOSControlCenter/nixos
[ OK ] Flake extras
[ OK ] Backup
[ OK ] Files synced
[ OK ] Passwords
[ OK ] Platform
[ OK ] Channel
Do you want to build and switch…? (y/n): y
[ OK ] Preflight
Building…
[ OK ] Switch
[ OK ] Update complete
```

| Line | Meaning |
|------|---------|
| `[ OK ] Config` | schema / heal OK |
| `[ OK ] Migrations` | module renames/orphans OK (no work or done) |
| `Source: …` | fact (not a check) — one line only |
| `[ OK ] Flake extras` | kept none, or merge ready |
| `[ OK ] Backup` | safety copy done (path only with `-v`) |
| `[ OK ] Files synced` | tree copy done (per-dir chatter only with `-v`) |
| `[ OK ] Passwords` / Platform / Channel | post-sync checks |
| `[ OK ] Preflight` | hardware/users (individual check lines only with `-v`) |
| `Building…` | wait; **no** rebuild dump |
| `[ OK ] Switch` | rebuild+activate succeeded |
| `[ OK ] Update complete` | parent final line |

Skip-build → one `Next: sudo ncc system build switch …`. Failure → `[ERROR]` + copyable log (always).

### With `-v` / `--verbose` (extra)

Everything above, plus:

- backup path, layout, per-module skip/copy, preserve notes, permissions
- migration “Scanning…” / “No pending…” detail
- each preflight check line (`[ OK ] CPU: …`)
- **full** `nixos-rebuild` + activation stdout
- optional `Next: ncc system report`

### Dry-run

Same checklist voice; banner `Preview only — nothing will be written…`; end with success + `Next: sudo ncc system update …`. Extras preview path OK in default; diffs only with `-v`.

### Flags

| Flag | Effect |
|------|--------|
| `--dry-run` / `-d` | Validate only, no writes / no sudo |
| `-v` | Technical detail + rebuild noise |
| `--yes` | Skip confirms (still merges extras) |
| `--drop-flake-extras` | Discard host flake extras (rare) |

---

## 5. How other command families should look

| Family | Normal | `-v` | Dry-run |
|--------|--------|------|---------|
| **system update** | Phases + merge preview + confirm | paths, diffs, JSON | full preview, no writes |
| **modules migrate** | Plan titles + success/would | layout, JSON preview | `--dry-run` |
| **config check / migrate-config** | valid / migrating / done | validation details | `--dry-run` validate+preview |
| **build / switch** | loading → success/fail | full log path | N/A (or nix dry-eval if added) |
| **install-wizard** | plain steps, same messages API | debug | `install dry-run` |
| **pre/postbuild checks** | `ui.badges` per check | why failed | N/A |
| **channel / release** | short status | JSON | prefer check-only flags |
| **TUIs** | tui-engine + formatter colors | — | — |
| **Machine JSON** | stdout JSON only; wrap human lines with formatter | — | — |

---

## 6. Per-module `CLI.md` (required if module has `commands.nix`)

Path: `<moduleRoot>/CLI.md`

Must include:
1. Link to this STANDARDS + COPY
2. Command list (`ncc …`)
3. Copy checklist (self-audit): formatter used? dry-run? `-v` gated?
4. Status: `compliant` / `partial` / `todo`

Template: [CLI.md.template](./CLI.md.template)

---

## 7. Audit checklist (repo-wide)

For each module with `commands.nix`:

- [ ] `CLI.md` exists and status is honest
- [ ] Scripts use `getModuleApi "cli-formatter"` (no hardcoded `config.core.management…`)
- [ ] No private `colors.nix` / `echo -e` / ANSI outside `cli-formatter`
- [ ] User lines via `ui.messages.*` or `ui.badges.*`
- [ ] Technical dumps only behind `-v`
- [ ] Mutating commands: dry-run or explicit “no dry-run” note in `CLI.md`
- [ ] Help text (`longHelp`) matches COPY tone
- [ ] README points to `CLI.md` (one line)

Validate (automated):

```bash
bash tests/cli-formatter/validate-cli.sh
```

What is / isn’t covered: [tests/cli-formatter/MANUAL.md](../../../../tests/cli-formatter/MANUAL.md)

---

## 8. Rollout order

1. **Done / in progress:** system-update, config-check dry-run, module-migrate, cli-registry sudo skip, COPY.md
2. **Next:** install-wizard logging → formatter; postbuild-checks ANSI → badges; channel-manager copy pass
3. **Then:** every `commands.nix` module gets `CLI.md` + README link
4. **Then:** add planned `ui.flow.*` helpers and migrate call sites
5. **Gate:** validate script green before claiming “CLI unified”
