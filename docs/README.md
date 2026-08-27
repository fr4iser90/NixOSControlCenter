# NCC documentation

Cross-cutting human docs. Product pitch: [root README](../README.md).

**Per-module depth** stays in `nixos/<module>/README.md` + `doc/` — do not copy it here.

## Naming & layout (law)

| Rule | |
|------|--|
| Filenames | **kebab-case** |
| Module docs | **only** `nixos/<module>/doc/` (+ root `README.md` stub) |
| Forbidden | `ai/docs/`, root `cli.md` / loose manuals |
| Gate | `tests/validate-docs-layout.sh` |
| Rules | `.cursor/rules/ncc-docs-layout.mdc`, `docs/developing/docs-conventions.md` |

## Target tree

```
docs/
  README.md                 ← this index
  install.md
  features.md
  domains.md
  limitations.md
  cli/
    pattern.md              ← ncc <domain> <action>
    migration.md            ← historical flat→domain
  gui/
    overview.md
    ui-matrix.md            ← CLI/TUI/GUI checklist
  tui/                      ← Bubble Tea drafts
    README.md
    …
  developing/
    new-module.md
    testing.md
    docs-conventions.md
```

## Index

### Product

| Doc | Purpose |
|-----|---------|
| [install.md](./install.md) | Bootstrap + `system-update` |
| [features.md](./features.md) | Present / partial / planned |
| [domains.md](./domains.md) | Domains ↔ modules |
| [limitations.md](./limitations.md) | Anti-cheat, fleet, … |

### Surfaces

| Doc | Purpose |
|-----|---------|
| [cli/pattern.md](./cli/pattern.md) | CLI contract |
| [cli/migration.md](./cli/migration.md) | Historical CLI migration |
| [gui/overview.md](./gui/overview.md) | Domain GUIs |
| [gui/ui-matrix.md](./gui/ui-matrix.md) | CLI / TUI / GUI matrix |
| [tui/](./tui/) | TUI integration drafts |

### Developing

| Doc | Purpose |
|-----|---------|
| [developing/new-module.md](./developing/new-module.md) | Add a module |
| [developing/testing.md](./developing/testing.md) | Gates → `tests/TESTING.md` |
| [developing/docs-conventions.md](./developing/docs-conventions.md) | Where docs go + kebab naming |

### Also trust (outside `docs/`)

| Location | Purpose |
|----------|---------|
| `nixos/**/README.md` + `doc/` | Domain SSOT |
| `gui-engine/doc/` | Page template, design, perf |
| `.cursor/rules/ncc-*.mdc` | Discovery, migrations, gates |
| `tests/TESTING.md` | Repo tests vs host preflight |
