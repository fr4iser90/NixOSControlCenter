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
- Hard gate `gates/validate-gui-catalog.sh` fails if `test_*.py` appears under `nixos/`.
- Store packages from modules must not `src = ../tests`.

## Layers (what to test)

```
5 Surfaces     CLI · GUI · TUI          → shared smoke, not per-domain E2E
4 Domain       scripts / page.py        → only when high risk
3 systemConfig options + wizard writes  → gates/validate-systemconfig-writes
2 Wiring       getModule* / migrations  → module-layer + migrations
1 Nix tree     parse / imports / bash   → gates/validate-ncc-nix (main net)
```

**Do not** create a full CLI+GUI+TUI suite per domain. Shared gates first; domain extras only for stacks/install/jetson/desktop-set style risk.

## Hard gates (before commit / system-update)

```bash
bash tests/run-gates.sh
# or:
bash tests/gates/validate-ncc-nix.sh              # Nix integrity + catalog invariants
bash tests/gates/validate-ncc-assistant-python.sh # assistant Python suite (needs pytest)
bash tests/gui/validate-gui-python.sh             # GUI Python (required in run-gates)
```

### ncc-assistant Python suite

Plain `unittest` + bare pytest functions over
[`nixos/modules/specialized/ncc-assistant`](nixos/modules/specialized/ncc-assistant)
— permission ladder, wrapper env semantics, notifications, companion source probes. No
PySide6 (Qt surfaces are gated by `gui/validate-gui-python.sh`). Interpreter:
`NCC_ASSISTANT_PYTHON` (explicit) or `python3`; **pytest is required** — with unittest alone
the bare functions would never run and the gate would report green.

**No desktop bubbles, no blocking waits.** The hooks run on a desktop where `notify-send`
exists, and the run path notifies on every terminal job state, so
[`ncc-assistant/conftest.py`](ncc-assistant/conftest.py) hides that binary for the whole
session (autouse `shutil.which` guard). Capability removal, not a convention: it also holds
for a test that forgets to stub, and it stops `notify_send_actions` from freezing the gate on
`--wait`. A test that needs the real argv patches `shutil.which` itself — its nested patch
wins. `test_desktop_quiet_gate_v1.py` fails if the guard disappears.

### What the session conftest isolates — and what it deliberately does not

Four capabilities are removed for the whole of `tests/ncc-assistant`:

| Guard | Capability removed | Why |
|-------|--------------------|-----|
| `pytest_configure` XDG throwaway | the operator's real config home | jobs, approvals, workspaces and audit resolve through `paths.config_home()` **on every call**, so one test driving the agent without its own tmp home appends to live state |
| `no_desktop_side_effects` (autouse) | `notify-send`, `qdbus`, `dbus-send`, `hyprctl`, `swaymsg`, `kdotool`, `wtype`, `xdotool`, `ydotool` from `shutil.which` | the gate runs on the desktop it would otherwise pause, switch workspace on, or type into |
| `operator_state_stays_writable_only_by_itself` (autouse tripwire) | nothing — it **fails the test** | `patch.dict(..., clear=True)` deletes the throwaway too, after which paths resolve to `~/.config`; the tripwire names the offending test instead of quietly editing the operator's history |
| `sys.dont_write_bytecode` | `.pyc` under the module tree | `package.nix` stages `core/ companion cli …` verbatim, so bytecode written by a local run is **content that ships** — a different store path per machine that ran the suite last |

**Not isolated: git's repository-location variables.** Measured inside a real `pre-commit` hook
(git 2.54.0), the environment the suite inherits is:

```
GIT_INDEX_FILE=.git/index   GIT_PREFIX=   GIT_AUTHOR_{NAME,EMAIL,DATE}
GIT_CONFIG_PARAMETERS=      GIT_EXEC_PATH= GIT_EDITOR=:
```

`GIT_DIR` / `GIT_WORK_TREE` are **not** exported, and a relative `GIT_INDEX_FILE` resolves against
the process cwd — so a fixture's `git add` / `commit` lands inside its own tmp repository, which is
why the current suites are safe. That is a property of *this git build behind this hook*, not a
guard we own: give the same command an absolute `GIT_DIR` (another git, a GUI commit tool, a wrapper
re-execing the hook) and it operates on the checkout running the gate — `GIT_DIR` beats both `-C` and
the working directory, verified directly by initialising a repository into a `GIT_DIR` target from an
unrelated cwd.

So a new test must not spawn real git unless it actually needs git. `_repo()` in
`test_permission_ladder_v1.py` does spawn it and inherits the variables above. Most cases that look
repository-shaped — *is this path inside a repo*, *what does the floor refuse*, *what environment did
the child get* — are served by a plain directory plus a stub executable on `PATH`, which is what
`test_gh_credential_v1.py` does for both `gh` and `git`. A strip guard for the nine location
variables exists on `refactor/ncc-assistant-tree` (`5a00bb35`: `conftest.py::GIT_REPO_ENV` +
`test_git_env_isolation_v1.py`); it is **deliberately not on `main`** — the exposure above is
accepted, not removed, and this section is where that choice is written down.

### PySide6 / Qt tests

NCC does **not** install PySide6 on system `python3`. The GUI uses a dedicated
`pythonEnv` (`gui-engine/package.nix`). The GUI gate resolves Python as:

1. `NCC_GUI_PYTHON` (explicit)
2. `python` from `ncc-gui` on PATH (after system-update)
3. `nix-build tests/gui/python-env.nix` (repo, first run may download)

Skip nix-build: `NCC_GUI_SKIP_NIX_PYTHON=1` (Qt tests skip; AST/smokes still run).

| Gate | Role |
|------|------|
| `gates/validate-ncc-nix.sh` | bash-in-nix, layer, migrations, wizard packaging, options SSOT, imports, prebuild + **imported config.nix** eval, **GUI catalog**, **module shape**, **AI packs**, **CLI/GUI surfaces** |
| `gui/validate-gui-python.sh` | page smoke, argv, fs_status, session_ux, hot-path; optional soak |
| `gates/validate-ncc-assistant-python.sh` | grant ladder, wrapper env (narrow-only, defaults not verdicts), notify wiring, companion probes |
| `gates/validate-assistant-layout.sh` | assistant tree: no `python/`/`ncc_assistant/`/`assistant/`, exact module package set, `$out` + site-root staging Soll-Menge, stdlib shadow + `sys.path` ban, `data/` catalog-only and complete, catalog loaders still load **from this tree's `data/`**, one entrypoint + `--help` smoke |
| `cli-formatter/validate-cli.sh` | Soft / optional — formatter/ANSI extras (`doc/cli.md` already hard-gated) |

`gates/validate-assistant-layout.sh` exists because **no other gate ever builds
`package.nix`** — the net only does `nix --parse`/`--eval`, so staging, PYTHONPATH and
entrypoints were unvalidated: a file could move, every wrapper break, and the gate stay green.
It checks what is provable *without* a Nix build (the staging targets are read out of the
`runCommand` text, the entrypoints are actually executed) and pins the two silent-failure
loaders (`playbooks`, `eval_harness`) by running them and reading back where the JSON came
from — including a throwaway `NCC_DATA_ROOT` proving the loaders follow *this* tree. The ban
on `python/` / `ncc_assistant/` / `assistant/` is absolute since the hoist landed; the tree
itself is specified in
[`doc/layout.md`](../nixos/modules/specialized/ncc-assistant/doc/layout.md) and the plan that
produced it, [`docs/todo/ncc-assistant-tree-layout-6b2a65d9.plan.md`](../docs/todo/ncc-assistant-tree-layout-6b2a65d9.plan.md).
Bite is proven per check in `ncc-assistant/test_layout_gate_v1.py`, which attacks a fixture
copy and requires each violation to turn the gate red.


Step 8 (`gates/validate-nix-module-eval.sh`) also force-evals `(import ./config.nix …)` values as NixOS modules (`lib.evalModules`). That catches top-level `lib.mkMerge` and mixed `config` + `warnings` — bugs that only showed up at `ncc system-update` before.

Uniformity steps inside `validate-ncc-nix` (12–14):

| Script | Enforces |
|--------|----------|
| `gates/validate-module-shape.sh` | discovery module ⇒ `template-config.nix` + `ai/manifest.nix` + `doc/usage.md` |
| `gates/validate-ai-packs.sh` | manifest `domain`/`description`; tools JSON fields + `risk` enum |
| `gates/validate-module-surfaces.sh` | `commands.nix` ⇒ `doc/cli.md` (+ Status); `page.py` ↔ `registerGuiPage` |
| `gates/validate-gui-hotpath.sh` | no live `nixpkgs`/catalog eval in `ui/gui`; `registerGuiEnv` for catalogs |
| `gates/validate-cli-manager-args.sh` | `ncc ai` argparse verbs ↔ `commands.nix` `arguments` + `main()` dispatcher |

Enable Git pre-commit:

```bash
# Usually unnecessary — run-gates.sh self-heals:
bash scripts/install-git-hooks.sh
```

That sets `core.hooksPath=.githooks` and installs `.git/hooks/pre-commit` (idempotent).

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
| Missing template / AI manifest / usage.md | module-shape |
| Broken AI tool JSON / risk | ai-packs |
| commands without `doc/cli.md` / dangling GUI page | module-surfaces |
| Live `nix-instantiate` / `<nixpkgs>` in GUI catalog | gui-hotpath |
| Missing `registerGuiEnv` for rice/catalog modules | gui-hotpath |
| GUI page import crash | gui-python smoke |
| FS status parse / Off badge data | `test_domain_fs_status.py` |
| Option exported but read by nobody | `test_schedule_notify_v1.py` |
| Wrapper overwrites what a schedule unit declared | `test_wrapper_grant_env_v1.py` |
| Gate pops desktop bubbles / hangs on `--wait` | `test_desktop_quiet_gate_v1.py` |
