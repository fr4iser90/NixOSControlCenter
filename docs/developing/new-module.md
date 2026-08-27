# Adding a new NCC module

How to add a **feature** module under `nixos/modules/` (or a core domain under `nixos/core/`).  
Laws live in `.cursor/rules/`; this page is the human checklist. Gates enforce the hard parts.

**Do not** maintain a separate `module-template/` tree — copy a small real module and follow this guide.

| Goal | Copy from |
|------|-----------|
| Small feature + GUI | `nixos/modules/system/lock-manager/` |
| Core domain (always in catalog) | `nixos/core/base/network/` or `hardware/` |
| GUI page only | `nixos/core/management/gui-engine/doc/page-template.md` |

---

## 1. Place it

```
nixos/modules/<group>/<name>/     # feature — infrastructure | security | system | specialized
nixos/core/base/<name>/           # core domain (hardware, packages, …)
nixos/core/management/<name>/     # management engines (rarely add new ones)
```

Folder **basename** = short module name used by discovery (`getModuleConfig "network"`).

Modules under `nixos/modules/` are discovered by the tree; do **not** hardcode peer paths or `import` other feature modules.

---

## 2. Required files

```
<module>/
  default.nix
  options.nix
  template-config.nix
  commands.nix
  config.nix                 # optional
  api.nix                    # optional
  README.md                  # short stub only (links into doc/)
  doc/                       # ONLY docs home for this module
    usage.md
    cli.md
    architecture.md
    ai-overview.md           # optional — assistant blurbs (ai-*.md)
    …
  ui/gui/page.py             # optional
  ui/tui/
  ai/                        # tools pack — NOT markdown docs
    manifest.nix
    tools/*.json
  migrations/
```

**One docs home: `doc/`.** No `ai/docs/`, no root `cli.md`.  
Assistant reads `doc/ai-*.md`. Tools stay in `ai/tools/`.  
Law: `.cursor/rules/ncc-docs-layout.mdc` · Gate: `tests/validate-docs-layout.sh`.

SSOT for AI packs: [`domain-ai-packs.md`](../../nixos/modules/specialized/ncc-assistant/doc/domain-ai-packs.md).

Tests go under **`tests/`** only — never `nixos/**/test_*.py`.

---

## 3. Identity + config (discovery only)

```nix
# default.nix (sketch)
{ config, lib, pkgs, getModuleConfig, getModuleApi, ... }:
let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "feature";           # or "core"
    name = moduleName;
    description = "…";
    category = "system";        # match folder group
    version = "1.0.0";
  };

  imports = [ ./options.nix ]
    ++ lib.optionals (cfg.enable or false) [
      ./commands.nix            # Core domains: often always import commands
      ./config.nix
    ];
}
```

**Core domains** that must stay visible in the GUI when disabled: register commands/GUI **outside** `mkIf enable`, and use `enabled = cfg.enable != false` (not `or true`).

```nix
# options.nix
{ lib, getCurrentModuleMetadata, ... }:
let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
    };
    enable = lib.mkEnableOption "…";
    # … your options
  };
}
```

```nix
# template-config.nix — plain attrset, no { lib }:
{
  enable = false;
  # defaults matching options
}
```

### Allowed helpers

```nix
cfg = getModuleConfig moduleName;
other = getModuleConfig "network";
api = getModuleApi "cli-registry";
tui = (getModuleApi "tui-engine").fromConfig config;
```

### Forbidden

- `config.core.management.…` / `systemConfig.core.base.…` path hardcoding
- `cfg = systemConfig.${configPath};` (dotted string ≠ nested path)
- `getModuleApi ? null` / `moduleName ? "desktop"` soft wiring
- Relative `import` of another module’s tree under `nixos/modules/`

Full law: [`.cursor/rules/ncc-module-discovery.mdc`](../../.cursor/rules/ncc-module-discovery.mdc).

Prefer `imports = [ ./commands.nix ];` so flake `specialArgs` inject helpers.  
Never `(import ./commands.nix { inherit … })` — drops helpers.

---

## 4. CLI registration

Use **cli-registry** via `getModuleApi`:

```nix
cliRegistry = getModuleApi "cli-registry";

config = lib.mkMerge [
  (cliRegistry.registerCommandsFor "my-module" [
    {
      name = "mymod";
      domain = "mymod";
      description = "…";
      script = entry;           # writeShellScriptBin
      # …
    }
  ])
];
```

Keep help text short; elevated ops go through existing NCC root patterns used by sibling modules.

---

## 5. GUI (optional)

1. Copy [`page-template.md`](../../nixos/core/management/gui-engine/doc/page-template.md) → `ui/gui/page.py`.
2. Register domain + page (feature: usually behind enable; **core**: always register):

```nix
(cliRegistry.registerGuiDomain "mymod" {
  label = "My Mod";
  description = "…";
  enabled = cfg.enable or false;   # feature
  group = "features";              # or "core"
})
(cliRegistry.registerGuiPage "mymod" ./ui/gui)
```

Design notes: `gui-engine/doc/gui-design.md`.  
Do not put unit tests next to `page.py`.

---

## 5b. Domain AI pack (optional)

```
<module>/
  doc/ai-overview.md      # assistant blurb (ai-*.md)
  ai/
    manifest.nix
    tools/<verb>.json
```

Example tool (`ai/tools/status.json`):

```json
{
  "name": "domain.desktop.status",
  "description": "Show current desktop settings.",
  "risk": "read",
  "permission": "desktop.read",
  "confirm": false,
  "inputSchema": { "type": "object", "properties": {} },
  "argv": ["ncc", "desktop", "status"]
}
```

Full contract: [`domain-ai-packs.md`](../../nixos/modules/specialized/ncc-assistant/doc/domain-ai-packs.md).

---

## 6. Version + migrations

Default: **no** version bump for docs, additive options, or internal refactors.

Bump `_version` / metadata `version` **and** add `<module>/migrations/vFROM-to-vTO.nix` only when hosts need cleanup (deleted packaging-sensitive paths, renames, breaking options).

```nix
# migrations/v1.0.0-to-v1.1.0.nix
{ lib }: {
  id = "my-module-1.0.0-to-1.1.0";
  from = "1.0.0";
  to = "1.1.0";
  description = "Why";
  removeRelativePaths = [ "scripts/obsolete.nix" ];
}
```

Details: [`.cursor/rules/ncc-module-migrations.mdc`](../../.cursor/rules/ncc-module-migrations.mdc).  
Gate: `tests/validate-module-migrations.sh` (via `validate-ncc-nix.sh`).

---

## 7. Checklist before claiming done

1. [ ] Tree under the right `core/` or `modules/<group>/` path  
2. [ ] `options.nix` uses `getCurrentModuleMetadata` / `options.${configPath}`  
3. [ ] `template-config.nix` defaults align with options  
4. [ ] Config reads only via `getModuleConfig` / APIs via `getModuleApi`  
5. [ ] CLI registered; GUI registered if you shipped a page  
5b. [ ] If assistant should call this domain: `ai/manifest.nix` (+ `tools/` as needed)  
6. [ ] No `test_*.py` under `nixos/`  
7. [ ] Migration only if breaking; version matches `to`  
8. [ ] **`bash tests/run-gates.sh`** exits 0  

Do **not** tell anyone to `ncc system-update` until step 8 is green in this turn.

---

## 8. Further reading

| Topic | Where |
|-------|--------|
| Testing strategy | [`testing.md`](./testing.md) → `tests/TESTING.md` |
| Domain AI packs | `nixos/modules/specialized/ncc-assistant/doc/domain-ai-packs.md` |
| Product overview | [`../../README.md`](../../README.md) |
| Install bootstrap | [`../install.md`](../install.md) |
| Agent rules | `.cursor/rules/ncc-*.mdc` |
