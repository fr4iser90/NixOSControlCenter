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
