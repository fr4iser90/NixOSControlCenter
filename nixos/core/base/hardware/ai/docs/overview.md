# hardware

CPU/GPU/RAM facts in systemConfig (written by install + prebuild checks).

## Config

- Read/write via `getModuleConfig "hardware"` (never hardcoded `config.core.…` paths).
- Template defaults: `template-config.nix` in this module.
- `gpu = "jetson"` → Tegra intent in systemConfig; Jetpack module comes from *host flake extras*
  (preserved by `ncc-check-flake-extras` / system-update — not hardcoded into NCC `flake.nix`).
  Optional `jetpack.*` keys apply only when the host already imports jetpack.

## CLI

- Prefer registered `ncc` commands for this module when they exist (`ncc --help` / domain help).
- Tools live in `ai/tools/*.json` only when a safe argv wrapper exists — none required for docs-only packs.

## Ownership

This pack is owned by the module. Delete `hardware/` ⇒ pack gone from assistant discovery.
