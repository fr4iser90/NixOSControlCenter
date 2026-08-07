# NixOS Control Center — AI / agent rules (enforced)

## 1. Discovery + systemConfig only (NON-NEGOTIABLE)

Everything a module needs for identity and config comes from:

| Source | Helper / mechanism |
|--------|--------------------|
| Own name | `moduleName = baseNameOf ./.` (or module root) |
| Own / peer config | `getModuleConfig <name>` (merges `template-config.nix` + systemConfig) |
| Peer API | `getModuleApi "<name>"` |
| Peer NixOS attrs | `(getModuleApi "<name>").fromConfig config` (on that module’s `api.nix`) |
| Paths | `getModuleMetadata` / `getCurrentModuleMetadata` → `configPath` |

**Forbidden**

- `getModuleNixConfig` (removed — use `(getModuleApi "…").fromConfig config`)
- `config.core.management.…` / `config.core.base.…`
- `systemConfig.core.base.desktop` (or any literal dotted path)
- `lib.attrByPath [ "core" "…" ] {} systemConfig`
- `import ../../../modules/…` / `import ../../../core/…` across modules
- `getModuleApi ? null`, `moduleName ? "desktop"`, any soft `?` on module wiring args

**Why this exists:** enable/disable, moves, and renames only work if discovery owns the path. Hardcodes break silently (`attrByPath` → `{}`) or explode late at rebuild.

## 2. Validate always

- Prefer path imports so flake `specialArgs` inject helpers:
  `imports = [ ./commands.nix ];` — **never** `(import ./commands.nix { inherit … })`
  (explicit inherit drops helpers and breaks rebuilds)

```bash
bash shell/scripts/checks/modules/validate-no-hardcoded-paths.sh
bash shell/scripts/checks/modules/validate-module-imports.sh
# or:
bash shell/scripts/checks/modules/run-all.sh
```

## 3. Module template

Canonical structure: `docs/AI/example-module/` + `MODULE_TEMPLATE.md`.

- Options: `options.${metadata.configPath}` only
- Config gated with `mkIf (cfg.enable or …)` for optional modules
- Commands register via `getModuleApi "cli-registry"`
- No stub tests that always `echo passed` — add real checks or call the validator above

## 4. Why the template failed us before

1. Docs said “generic, not hardcoded” but **CI did not scan** for `config.core.…`
2. Example tests were stubs (`echo "Tests passed"`)
3. Soft defaults (`? null`) and `attrByPath … {}` **hid** mistakes until a dependent attr was missing
4. `docs/AI/RULES.md` / CHECKS were empty — agents had no always-on rule

This file + `.cursor/rules/ncc-module-discovery.mdc` + the shell validator close that gap.
