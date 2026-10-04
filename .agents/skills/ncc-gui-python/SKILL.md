---
name: ncc-gui-python
description: >-
  Edit NCC GUI domain pages and gui-engine Python safely: catalog invariants,
  no tests under nixos/, PySide6 via ncc-gui env, smoke gates. Use when changing
  ui/gui/page.py, ncc_gui/, gui-engine, or GUI catalog registration.
---

# NCC GUI Python

## Laws

- Domain pages: `ui/gui/page.py` under the owning module
- Engine: `nixos/core/management/gui-engine/python/ncc_gui/`
- **Never** add `nixos/**/test_*.py` (would deploy). Suites live in `tests/gui/`
- Catalog: domains register via commands; gate `tests/gates/validate-gui-catalog.sh`
- Heavy catalogs: bake JSON + `registerGuiEnv` → `NCC_*_CATALOG`. **Never**
  `nix-instantiate` / `import <nixpkgs>` in `ui/gui` (gate: `validate-gui-hotpath`)
- Sidebar rules: `ncc_gui/nav_visibility.py` (Core alwaysVisible; Features + Hide inactive)
- Page load: uniform kit protocol — `schedule_load` + `begin_load`/`end_load` /
  `load_ncc_status`; never sync `self.reload()` in `__init__`. Gate:
  `tests/gui/test_page_load_states.py` (contract + UI-thread ≤50 ms with stubbed
  `ncc`; live `ready in` is debug-only). Doc: `gui-engine/doc/page-load.md`

## Python env

GUI is **not** system `python3` + PySide6. Prefer:

1. `NCC_GUI_PYTHON`
2. `python` from `ncc-gui` on PATH
3. `nix-build tests/gui/python-env.nix`

## After edits

```bash
bash tests/run-gates.sh
# or at least:
bash tests/gui/validate-gui-python.sh
bash tests/gates/validate-gui-catalog.sh
```

Design notes: `nixos/core/management/gui-engine/doc/gui-design.md`.  
Page template: `nixos/core/management/gui-engine/doc/page-template.md`.
