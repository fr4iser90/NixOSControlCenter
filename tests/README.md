# NCC tests

**Strategy SSOT:** [TESTING.md](./TESTING.md)  
(Where tests live, layers, hard gates, no tests in the product.)

## Quick answers

| Question | Answer |
|----------|--------|
| Tests in module or `tests/`? | **Only `tests/`** for suites |
| Tests in end product (`/etc/nixos`)? | **No** — never put `test_*.py` under `nixos/` |

## Hard gates (run before commit / system-update)

```bash
bash tests/run-gates.sh
```

Minimum Nix + catalog gate alone:

```bash
bash tests/gates/validate-ncc-nix.sh
```

Git pre-commit is wired by `scripts/install-git-hooks.sh` (also self-heals from `run-gates.sh`):

```bash
bash scripts/install-git-hooks.sh
```

## Layout

```
tests/
  TESTING.md                 Strategy (read this)
  run-gates.sh               Entry — all hard gates
  gates/                     Hard-gate validate-*.sh (Nix / layer / docs / catalog)
    validate-ncc-nix.sh      Orchestrator for Nix integrity gates
  gui/                       GUI Python smoke + unit (hard via run-gates)
  install-wizard/            Wizard + remote deploy (subset in hard gate)
  lib/                       Shared Nix eval helpers
  cli-formatter/             Soft / optional CLI formatter + docs audit
  hardware/                  Soft / optional host-specific (e.g. Jetson)
  ncc-assistant/             Soft / optional assistant unit tests
  packages/                  Soft / optional packages intent store
  ai-workspace-training/     Soft / optional GPU bench (not a gate)
```

## Why `.sh` and `.py` mixed?

| Kind | Format | Examples |
|------|--------|----------|
| Nix / packaging / bash scripts | **`.sh`** (+ some `.nix` wrappers) | `gates/validate-ncc-nix.sh`, `gates/validate-systemconfig-writes.sh` |
| Python app logic (GUI, wizard, assistant) | **`.py`** | `tests/gui/`, `test_wizard_logic.py` |

Shell gates must source install-wizard bash and call `nix-instantiate`. Python tests stay next to the Python concerns they exercise — still under **`tests/`**, not under `nixos/`.

**Do not** migrate shell installer gates to Python. Add new **semantic config** checks via Nix eval (`tests/lib/systemconfig-options-check.nix`) and a thin `.sh` driver under `gates/`.

## systemConfig SSOT validation

`gates/validate-systemconfig-writes.sh`:

1. Runs `apply_install_template` for Desktop, Server, Jetson, fr4iser-home
2. Loads staged leaves with `config-loader.nix`
3. Evaluates `lib.evalModules` against each module's `options.nix`

## Import path gates

| Script | What |
|--------|------|
| `gates/validate-nix-import-paths.sh` | Static `import ./…` resolve + parse all `.nix` |
| `gates/validate-nix-module-eval.sh` | Eval prebuild-checks + `import ./config.nix` module shapes |
| `gates/validate-gui-catalog.sh` | Catalog invariants + no tests under `nixos/` |
| `gates/validate-module-shape.sh` | Uniform skeleton: template-config + AI manifest + usage.md |
| `gates/validate-ai-packs.sh` | AI pack manifest + tools JSON contract |
| `gates/validate-module-surfaces.sh` | `commands.nix` ↔ `doc/cli.md` ↔ GUI `page.py` |
| `gates/validate-gui-hotpath.sh` | No live catalog eval in GUI; `registerGuiEnv` for catalogs |
