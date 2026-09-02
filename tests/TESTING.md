# NCC testing strategy (SSOT)

## Where do tests live?

| Location | Allowed? | Why |
|----------|----------|-----|
| **`tests/`** (repo root) | **Yes — only place for suites** | Never synced to `/etc/nixos`; agents/CI run here |
| **`nixos/**/test_*.py`** | **Forbidden** | `system-update` / remote push sync the **nixos/** tree → tests would land on hosts |
| Inside a module as product code (`vm/testing/`) | OK only if it is a **feature** (test VMs), not a unit suite | Not a pytest/unittest gate |

**Answer:** tests in **`tests/`**, never in modules for unit/integration suites.

## Do tests land in the end product?

**No.**

- Deploy path syncs **`nixos/`** (and Host staging), not the git `tests/` tree.
- Hard gate `validate-gui-catalog.sh` fails if `test_*.py` appears under `nixos/`.
- Store packages from modules must not `src = ../tests`.

## Layers (what to test)

```
5 Surfaces     CLI · GUI · TUI          → shared smoke, not per-domain E2E
4 Domain       scripts / page.py        → only when high risk
3 systemConfig options + wizard writes  → validate-systemconfig-writes
2 Wiring       getModule* / migrations  → module-layer + migrations
1 Nix tree     parse / imports / bash   → validate-ncc-nix (main net)
```

**Do not** create a full CLI+GUI+TUI suite per domain. Shared gates first; domain extras only for stacks/install/jetson/desktop-set style risk.

## Hard gates (before commit / system-update)

```bash
bash tests/run-gates.sh
# or:
bash tests/validate-ncc-nix.sh   # Nix integrity + catalog invariants
bash tests/gui/validate-gui-python.sh   # GUI Python (required in run-gates)
```

### PySide6 / Qt tests

NCC does **not** install PySide6 on system `python3`. The GUI uses a dedicated
`pythonEnv` (`gui-engine/package.nix`). The GUI gate resolves Python as:

1. `NCC_GUI_PYTHON` (explicit)
2. `python` from `ncc-gui` on PATH (after system-update)
3. `nix-build tests/gui/python-env.nix` (repo, first run may download)

Skip nix-build: `NCC_GUI_SKIP_NIX_PYTHON=1` (Qt tests skip; AST/smokes still run).

| Gate | Role |
|------|------|
| `validate-ncc-nix.sh` | bash-in-nix, layer, migrations, wizard packaging, options SSOT, imports, prebuild + **imported config.nix** eval, **GUI catalog** |

Step 8 (`validate-nix-module-eval.sh`) also force-evals `(import ./config.nix …)` values as NixOS modules (`lib.evalModules`). That catches top-level `lib.mkMerge` and mixed `config` + `warnings` — bugs that only showed up at `ncc system-update` before.
| `gui/validate-gui-python.sh` | page smoke, argv, fs_status, session_ux, hot-path; optional soak |
| `cli-formatter/validate-cli.sh` | CLI docs/formatter (via `tests/default.nix` / optional) |

Enable Git pre-commit (automatic):

```bash
# Usually unnecessary — Cursor sessionStart + run-gates.sh call:
bash scripts/install-git-hooks.sh
```

That sets `core.hooksPath=.githooks` and installs `.git/hooks/pre-commit` (idempotent).  
No manual `git config` needed for normal clones.

## Soft / optional

| Suite | When |
|-------|------|
| `NCC_GUI_SOAK=1` | Long GUI soak |
| `tests/install-wizard/*` heavy | Before remote install changes |
| `tests/hardware/jetson/*` | Jetson flake extras |
| `tests/ai-workspace-training/` | GPU bench — **not** a deploy gate |

## Adding a new domain

1. Implement under `nixos/…` (commands + optional `ui/gui`, `ui/tui`).
2. Ensure Core: `registerGuiDomain` + `registerGuiPage` **outside** enable `mkIf`; never `enable or true`.
3. Run `bash tests/run-gates.sh` — must exit 0.
4. Add a **shared** test only if new parser/logic (prefer `tests/gui/test_*.py`).
5. Do **not** add `nixos/.../test_*.py`.

## Corrupt-deploy classes these gates catch

| Failure | Gate |
|---------|------|
| Broken relative `import` | import-paths + module-eval |
| `${}` bash-in-nix | bash-embedding |
| Missing migration after delete | migrations |
| Wizard writes invalid options | systemconfig-writes |
| `false or true` enable | gui-catalog |
| Tests shipping in product | gui-catalog |
| GUI page import crash | gui-python smoke |
| FS status parse / Off badge data | `test_domain_fs_status.py` |
