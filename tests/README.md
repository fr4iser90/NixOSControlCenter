# NCC tests

## Hard gates (run before commit / system-update)

```bash
bash tests/run-gates.sh
```

Minimum Nix gate alone:

```bash
bash tests/validate-ncc-nix.sh
```

Enable optional pre-commit hook (once per clone):

```bash
git config core.hooksPath .githooks
```

## Why `.sh` and `.py` mixed?

| Kind | Format | Examples |
|------|--------|----------|
| Nix / packaging / bash scripts | **`.sh`** (+ some `.nix` wrappers) | `validate-ncc-nix.sh`, `validate-systemconfig-writes.sh`, `test-presets-dry-run` |
| Python app logic (GUI, wizard, assistant) | **`.py`** | `tests/gui/`, `test_wizard_logic.py`, `test_remote_preflight.py` |

Shell gates must source install-wizard bash and call `nix-instantiate` — converting those to Python would add indirection without benefit. Python tests stay next to the Python code they exercise.

**Do not** migrate shell installer gates to Python. Add new **semantic config** checks via Nix eval (`tests/lib/systemconfig-options-check.nix`) and a thin `.sh` driver.

## systemConfig SSOT validation

`validate-systemconfig-writes.sh`:

1. Runs `apply_install_template` for Desktop, Server, Jetson, fr4iser-home
2. Loads staged leaves with `config-loader.nix`
3. Evaluates `lib.evalModules` against each module's `options.nix`

Module `options.nix` types are the source of truth; the wizard must not write invalid enums or shapes.
