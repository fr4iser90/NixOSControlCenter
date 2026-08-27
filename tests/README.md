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
bash tests/validate-ncc-nix.sh
```

Enable optional pre-commit hook (once per clone):

```bash
git config core.hooksPath .githooks
```

## Layout

```
tests/
  TESTING.md                 Strategy (read this)
  run-gates.sh               All hard gates
  validate-ncc-nix.sh        Nix integrity + catalog invariants
  validate-gui-catalog.sh    enable/or-true, core domain+page, no test leak
  gui/validate-gui-python.sh GUI Python smoke + unit
  gui/test_*.py              GUI / push_tree / fs_status / session
  install-wizard/            Wizard + remote deploy
  lib/                       Shared Nix eval helpers
  cli-formatter/             CLI formatter docs gate
  hardware/                  Optional host-specific
  ncc-assistant/             Assistant unit tests
  packages/                  Packages intent store
  ai-workspace-training/     Optional GPU bench (not a gate)
```

## Why `.sh` and `.py` mixed?

| Kind | Format | Examples |
|------|--------|----------|
| Nix / packaging / bash scripts | **`.sh`** (+ some `.nix` wrappers) | `validate-ncc-nix.sh`, `validate-systemconfig-writes.sh` |
| Python app logic (GUI, wizard, assistant) | **`.py`** | `tests/gui/`, `test_wizard_logic.py` |

Shell gates must source install-wizard bash and call `nix-instantiate`. Python tests stay next to the Python concerns they exercise — still under **`tests/`**, not under `nixos/`.

**Do not** migrate shell installer gates to Python. Add new **semantic config** checks via Nix eval (`tests/lib/systemconfig-options-check.nix`) and a thin `.sh` driver.

## systemConfig SSOT validation

`validate-systemconfig-writes.sh`:

1. Runs `apply_install_template` for Desktop, Server, Jetson, fr4iser-home
2. Loads staged leaves with `config-loader.nix`
3. Evaluates `lib.evalModules` against each module's `options.nix`

## Import path gates

| Script | What |
|--------|------|
| `validate-nix-import-paths.sh` | Static `import ./…` resolve + parse all `.nix` |
| `validate-nix-module-eval.sh` | Eval prebuild-check modules (imports in `let`) |
| `validate-gui-catalog.sh` | Catalog invariants + no tests under `nixos/` |
