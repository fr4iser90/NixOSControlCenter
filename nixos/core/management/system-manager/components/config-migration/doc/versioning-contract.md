# Versioning contract (schema vs module)

Two version tracks. Do not merge them. Do not hardcode release strings in GUI/Bash beyond the single SSOT.

## 1. Config schema — `configVersion`

| | |
|---|---|
| **What** | Shape of fleet `systemConfig` (layout, required fields, e.g. `system.platform`) |
| **Where** | `systemConfig/…/system-manager/config.nix` (or monolith) |
| **SSOT target** | `schema.nix` → `currentVersion` |
| **Plans** | `schema/migrations/vFROM-to-vTO.nix` (discovered) |
| **Engine** | `ncc-migrate-config` |
| **Form** | `major.minor` (`2.0`, `2.1`) |

### Rules

1. **One SSOT:** bump `schema.currentVersion` when shipping a new schema file; add `schema/vX.Y.nix` + `migrations/vA-to-vB.nix`.
2. **Every plan must leave the leaf at `to`:** `inject.configVersion` and/or engine `ncc_migrate_bump_config_version "$to"`. No-op field work still bumps.
3. **No version-specific early exits in Bash** (`if 2.0 then …`). Use detect → chain → per-step apply (`liveInject`, inject, layout hints) → bump to step target.
4. **GUI/CLI expected version:** `NCC_EXPECTED_CONFIG_VERSION` from Nix (`schema.currentVersion`). Probe live `configVersion`; banner = `live < expected`. Never hardcode `2.1` in Python except as last-resort fallback for unpackaged tests.
5. **Heal path:** if already at `currentVersion`, only repair (stale files, missing `system.platform`) — do not invent a new version.

### Plan shape (minimum)

```nix
{
  description = "…";
  fieldsToKeep = [ /* … */ ];
  fieldsToMigrate = {
    systemManager = {
      targetFile = "core/management/system-manager/config.nix";
      inject = { configVersion = "X.Y"; /* optional layout, … */ };
    };
  };
  layoutConversion = false;
  # Optional live values applied by the engine (not baked into the plan):
  liveInject = { "system.platform" = "uname-m"; };
}
```

## 2. Module code — `_module.metadata.version`

| | |
|---|---|
| **What** | On-disk module tree / packaging cleanup |
| **Where** | module `default.nix` + options `_version` |
| **State** | `/var/lib/ncc/module-migrations.json` |
| **Plans** | `<module>/migrations/vFROM-to-vTO.nix` |
| **Engine** | `ncc-apply-migrations` / `ncc-module-migrate` |
| **Form** | SemVer `1.2.3` |

Bump only when hosts need cleanup (orphans, renames). Cross-module rename/merge lives in the **destination** module’s `migrations/plan-*.nix` (discovered by `ncc-module-migrate`). Central `plans.nix` stays empty.

## Why two tracks

Same idea as DB schema version vs app package version: schema drifts slowly and is fleet-wide; module cleanups are frequent and isolated. Mixing them makes the GUI banner wrong and migrations non-generic.
