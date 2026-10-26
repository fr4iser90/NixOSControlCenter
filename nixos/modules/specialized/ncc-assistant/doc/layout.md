# ncc-assistant — tree layout (SSOT)

Which directory owns what, and what the packaging contract is around it.
If a file move conflicts with this file, **this file wins** — and
`tests/gates/validate-assistant-layout.sh` goes red on it.

Product surfaces (what the user sees) are defined in [surfaces.md](surfaces.md);
this file is about where their **code** lives.

---

## Top level

| Path | Purpose | Importable? |
|------|---------|-------------|
| `default.nix` `options.nix` `commands.nix` `api.nix` `package.nix` `schedules.nix` `template-config.nix` | the Nix module | — |
| `lib/` | Nix helpers (`discover-domain-ai.nix`, `discover-modules-index.nix`) | — |
| `doc/` | all module prose (this file, `usage.md`, `cli.md`, `surfaces.md`, `plans/`) | — |
| `ai/` | the module's domain-AI pack (`manifest.nix`, `skills/`, `domains/`, `context/`) | — |
| `ui/gui/page.py` | **the NCC shell page** — Control-Center embeds this | via gui-engine, not here |
| `data/` | **catalogs only** — JSON/MD, never a `.py` | no, reached by path |
| `companion/` | Surface: the avatar overlay (`ncc ai companion`) | yes |
| `window/` | Surface: the multi-tab assistant window (`ncc ai gui`) | yes |
| `tray/` | Surface: the tray daemon (`ncc ai tray`) | yes |
| `widgets/` | Qt building blocks **shared** by the surfaces above | yes |
| `core/` | shared logic, Qt-free, grouped (see below) | yes |
| `cli/` | the single entrypoint (`python -m cli`) | yes |
| `harness/` | coding-harness adapters (native / qwen / dsh) | yes |
| `plugins/` | feature plugins (`doomscroll/`, `morning_brief/`) | yes |

Four Qt surfaces, not one. That split is **measured, not stylistic**: `pages`, `templates`,
and `providers` hang off both the window and the companion at the same time, so `widgets/` is
the only home that does not create a `window → companion` edge (and a cycle behind it).

**There is no `python/`, no `ncc_assistant/`, no `assistant/`.** The module root is not a
Python package — `ai/`, `doc/`, `lib/`, `ui/` would become importable namespace noise the
moment it was, and `lib/` holds nothing but `.nix`.

---

## `core/` — groups, not a flat pile

| Group | Owns |
|-------|------|
| `core/runtime/` | tool runtime, agent runner, registry, session, memory |
| `core/store/` | settings, paths, jobs, presence, preferences (state on disk) |
| `core/policy/` | permission ladder, floor rules, audit, red-team pack |
| `core/scheduling/` | schedules, grants per scope, frequency parsing |
| `core/catalogs/` | agent templates, playbooks, eval cases, marketplace, MCP catalog |
| `core/workflows/` | workflow execution incl. the git pathset rules |
| `core/render/` | transcript / text rendering (Qt-free) |

`core/__init__.py` re-exports the public API; import from the group you mean
(`from core.catalogs.playbooks import list_playbooks`), because the façade imports everything
including the heavy halves.

---

## Where a new file goes

1. **Does it draw a window?** → the surface that owns it. Shared between two surfaces →
   `widgets/`. A page inside the Control-Center shell → `ui/gui/page.py`, never here.
2. **Is it logic a surface and the CLI both need?** → the matching `core/<group>/`. A new
   group is a layout decision: update this file and the gate in the same change.
3. **Is it data the shipped assistant reads?** → `data/`. Nothing under `data/` may be a
   `.py`; nothing under `data/` is importable.
4. **Is it a new top-level package?** → only with a reason this file cannot already cover.
   It is a new name on PYTHONPATH for *every* NCC GUI, so
   `validate-assistant-layout.sh` requires it in three Soll-Mengen at once.

---

## Data root

Catalogs left the importable package, so `importlib.resources` cannot reach them. One
resolver answers for all of them — `core.store.paths.data_root()`:

```python
env NCC_DATA_ROOT  →  packaged: ${appRoot}/data
else               →  <module>/data            # dev checkout
```

`NCC_PROMPTS_ROOT` works the same way and defaults to `NCC_DATA_ROOT/prompts`. Both are
exported by this module's own wrappers (`package.nix` → `envExports`) and handed to the GUI
through `guiEnv` below — gui-engine forwards them, it never derives them. An assistant process
without them is running from a source tree, not from a store path.

Loaders must not swallow a missing root into an empty list — that is the failure mode the
witness tests exist for (`tests/ncc-assistant/test_catalog_loaders_v1.py`).

---

## Packaging

`package.nix` builds `appRoot` (`ncc-assistant-src`) as the only PYTHONPATH entry:

```
$out/lib/ncc-assistant/{cli,companion,core,harness,plugins,tray,widgets,window}
$out/lib/ncc-assistant/ncc_gui        # from gui-engine.src
$out/data                             # catalogs, NOT on PYTHONPATH
$out/knowledge                        # built from <module>/ai/ packs — see below
$out/AI_KNOWLEDGE.md
```

`knowledge/` in this source tree is only a README: `$out/knowledge` is **generated** at build
time from the discovered `ai/` packs of every module
(`lib/discover-domain-ai.nix` → `NCC_KNOWLEDGE_ROOT`). Skills the assistant itself ships are
`ai/skills/` here and `data/prompts/skills/` at runtime.

Every wrapper binds the same entrypoint — `python -m cli` (+ `mcp` / `tray` / `companion` for
the dedicated binaries).

### GUI payload contract

The `ai` page (`ui/gui/page.py`) imports these packages, so it needs them staged. It asks for
them through cli-registry rather than being listed inside gui-engine:

```nix
guiPythonRoot = "${appRoot}/lib/ncc-assistant";   # children = importable packages
guiEnv        = { NCC_DATA_ROOT; NCC_PROMPTS_ROOT; };
guiFingerprint = [ domainAi.indexFile ];           # read by path → path change is hard
```

`commands.nix` registers all three with `registerGuiPython "ai"` **inside the same
`mkIf (cfg.enable or false)`** that ships the packages. gui-engine copies `guiPythonRoot`'s
children and exports `guiEnv` — the list above is the only place the package names exist
outside this module.

---

## Reload coupling

`ncc_gui/reload.py` digests what the GUI wrappers on the profile actually stage: any directory
with an `__init__.py` under their PYTHONPATH root. It never names this module's packages, so a
new surface package is digested without touching the engine. `data/` has no `__init__.py` and is
therefore **not** digested — a catalog edit must never restart a running GUI. Files a payload
reads by path (not tree-hashable) go through `guiFingerprint` → `NCC_GUI_FINGERPRINT`, where a
changed store path is a hard restart.

---

## Gate

`tests/gates/validate-assistant-layout.sh` enforces this without building anything: banned
legacy roots, the module's package set, the two staging Soll-Mengen, stdlib shadowing and any
`sys.path` edit, `data/` staying code-only and complete, both catalog loaders loading *from
this tree's* `data/`, and one entrypoint answering `--help`. Its negative proof is
`tests/ncc-assistant/test_layout_gate_v1.py`.
