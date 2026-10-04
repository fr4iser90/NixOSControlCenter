---
name: ncc-hard-gates
description: >-
  Run NCC hard gates before finishing nixos/ changes or telling the user to
  ncc system-update. Use when editing nixos/, validating, pre-update, claiming
  "validated", or after migrations/bash-in-nix/GUI/catalog work.
---

# NCC hard gates

## Mandatory

After any change under `nixos/` (or when the user will `system-update`):

```bash
bash tests/run-gates.sh
```

Require **exit 0 in this turn**. Prefer this over `gates/validate-ncc-nix.sh` alone (includes GUI Python smoke).

## Forbidden

- Claiming “validated” / “safe to update” without exit 0
- Telling the user to `ncc system-update` without exit 0
- Treating `nix-instantiate --parse` on one file as enough

## What `run-gates` covers

| Gate | Catches |
|------|---------|
| bash-in-nix | `${…}` in `''` strings; parse of key handlers |
| module layer | empty plans registry; no peer hardwires |
| migrations auto-detect | packaging-sensitive deletes without `migrations/` |
| install-wizard packaging | same path as system-update sync |
| options SSOT | wizard writes vs `options.nix` |
| GUI catalog | no `test_*.py` under `nixos/`; domain registration |
| docs layout | markdown under `doc/` + kebab-case |
| module shape | every discovery module: `template-config` + `ai/manifest` + `doc/usage.md` |
| AI packs | tool JSON fields + `risk`; manifest `domain`/`description` |
| surfaces | `commands.nix` ⇒ `doc/cli.md`; `page.py` ↔ `registerGuiPage` |
| gui-python | page smoke / argv / session |

Details: [tests/TESTING.md](../../../tests/TESTING.md).

## After green

User deploys: `ncc system-update --local /path/to/repo/nixos`.  
Agents do **not** poke `/etc/nixos`.
