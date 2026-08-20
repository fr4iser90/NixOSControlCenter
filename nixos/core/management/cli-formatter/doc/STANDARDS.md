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

## 3. Command UX skeleton (every mutating `ncc …` command)

```
1. header          ui.text.header "…"
2. (optional) dry  banner if --dry-run
3. loading         ui.messages.loading "…"
4. facts           ui.tables.keyValue / short info  (−v for more)
5. work            …
6. result          success | warning | error
7. next            one clear next command (info)
```

**Forbidden in normal mode:** raw `Layout: monolith`, full jq dumps, store paths, stack traces.
**Allowed in `-v`:** all of the above.

**Dry-run:** never write `/etc/nixos` (or other live roots). Skip dangerous prompts. Skip sudo when `--dry-run` (cli-registry already does this).

---

## 4. How `ncc system update` MUST look

### Dry-run (validate)

```text
=== NixOS System Update (dry-run) ===
Preview only — nothing will be written under /etc/nixos

Checking system configuration…
Configuration is valid
Checking module config migrations…
Plan …: rename … → …          # short
Would rename (dry-run) — no changes written
…                             # JSON only with -v

=== Extra software sources on this machine ===
These will be kept and merged into the update.
  • jetpack
Preparing merged update preview…
Preview ready — extras will be kept
Preview: /tmp/ncc-flake-update-preview.nix

Dry-run OK — safe to run the real update when ready
Next: sudo ncc system update --local --source-dir "…"
```

### Real update

```text
=== NixOS System Update ===
(dangerous confirm unless --yes)
… config check / migrations (may write) …
… source resolve …
=== Extra software sources … ===   # if any; always keep unless --drop-flake-extras
Continue update? [Y/n]
Creating a safety backup…          # path only with -v
… sync / copy …
… build prompt or --auto-build …
success / clear failure + next hint
```

### Flags users care about

| Flag | Effect |
|------|--------|
| `--dry-run` / `-d` | Validate only, no sudo |
| `-v` | Technical detail |
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
