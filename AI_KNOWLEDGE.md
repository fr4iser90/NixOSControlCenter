# AI Knowledge: NixOSControlCenter

## Purpose
NixOSControlCenter (NCC) — a NixOS system management tool with CLI commands, modular config system,
prebuild hardware checks, declarative user/package/device management, and homelab/VM/SSH functionality.

---

## Directory Structure

```
NixOSControlCenter/
├── nixos/                    # ACTIVE CODE — all runtime logic
│   ├── core/                 # system-level NixOS modules
│   │   ├── base/             #   base OS config (boot, network, audio, hardware, user, desktop, packages, localization)
│   │   └── management/       #   management tools (system-manager, cli-registry, cli-formatter, module-manager, tui-engine)
│   ├── modules/              # higher-level application modules (infrastructure, security, specialized, system)
│   ├── custom/               # user's custom NixOS modules (preserved across updates, never overwritten)
│   └── systemConfig/         # RUNTIME config (v1) — symlinked from /etc/nixos/systemConfig/
│
├── docs/                     # LEGACY docs — NOT maintained, exists for historical reference only
├── nixify/                   # EMPTY — placeholder for future nixify.io integration
├── chronicle/                # EMPTY — placeholder for future chronicle documentation system
├── hackathon/                # EMPTY — placeholder for hackathon assets
├── shell/                    # devShell entry point
└── notes/                    # local dev notes (not part of project)
```

---

## Architecture: core vs modules

### core/ — System-Level Modules
These are the fundamental NixOS configuration modules. They define the OS itself.

```
core/
├── base/           # Boot, network, audio, hardware detection, user management, desktop, packages, localization
│   ├── boot/
│   ├── network/
│   ├── audio/
│   ├── hardware/   # hardware-config.nix (CPU/GPU/Memory detection + config)
│   ├── user/       # user accounts, passwords
│   ├── desktop/    # desktop environment (plasma, gnome, etc.)
│   ├── packages/   # system packages
│   └── localization/
└── management/     # Management tooling
    ├── system-manager/    # THE KEY MODULE — orchestrates system-update, backup, config-migration
    ├── cli-registry/      # CLI command registration system (ncc is built here)
    ├── cli-formatter/     # Output formatting (colored messages, tables, badges)
    ├── module-manager/    # Module loading, config merging with template defaults
    └── tui-engine/        # Terminal UI framework for interactive commands
```

### modules/ — Application Modules
Higher-level functionality built on top of core.

```
modules/
├── infrastructure/   # VM management, homelab, bootentry-manager, docker
├── security/         # Security policies, firewall
├── specialized/      # chronicle (documentation gen), AI workspace, SSH management
└── system/           # System-level tools, cleanup
```

### packages/
Custom package definitions. Usually empty — most packages come from nixpkgs.

### custom/
User's personal NixOS modules. **Never overwritten** during updates — preserved as-is.

---

## Config System: v0 → v1 Migration

| Version | Config Location | Entry Point | Status |
|---------|----------------|-------------|--------|
| v0 (legacy) | `/etc/nixos/system-config.nix` | flake.nix → imports system-config.nix | DEPRECATED, being removed |
| v1 (current) | `/etc/nixos/systemConfig/**/config.nix` | flake.nix → config-loader.nix → recursive discover | **ACTIVE** |

### v1 Config Structure
```
systemConfig/
├── core/
│   ├── base/
│   │   ├── audio/config.nix
│   │   ├── boot/config.nix
│   │   ├── network/config.nix
│   │   ├── hardware/config.nix     (CPU/GPU/RAM detection)
│   │   ├── user/config.nix
│   │   ├── desktop/config.nix
│   │   ├── packages/config.nix
│   │   └── localization/config.nix
│   └── management/
│       └── system-manager/config.nix  (holds configVersion = "1.0")
└── modules/
    ├── infrastructure/*/config.nix
    ├── security/*/config.nix
    ├── specialized/*/config.nix
    └── system/*/config.nix
```

### Key Rules
- **configVersion = "1.0"** lives in `systemConfig/core/management/system-manager/config.nix`
- **No system-config.nix** on v1 — it's deleted after migration (backup exists in `/var/backup/nixos/`)
- **Aggregator config.nix files** (in intermediate directories like `core/base/config.nix`) are DELETED after migration — they were v0 artifacts
- **Leaf config.nix files** at depth 3+ (e.g., `core/base/audio/config.nix`) are the real configs
- **template-config.nix** files in modules serve as default/template configs, copied to `config.nix` on first install

### Migration Flow (v0 → v1)
1. `/etc/nixos/system-config.nix` loaded as JSON via nix-instantiate
2. Fields extracted by jq per migration plan in `schema/migrations/v0-to-v1.nix`
3. Config files written to `systemConfig/**/config.nix`
4. `system-config.nix` **deleted** (backup exists)
5. Aggregator config.nix files **deleted**
6. `configVersion = "1.0"` injected into `system-manager/config.nix`

---

## Update Flow (`ncc system-update`)

```
┌─────────────────────────────────────────────────────┐
│ 1. Validation (ncc-validate-config / validator.nix) │
│    • Checks systemConfig/ structure                 │
│    • Detects config version (v0→v1)                │
│    • Recursively validates all config.nix files     │
│    • Exits with error → triggers migration         │
└─────────────────────┬───────────────────────────────┘
                      │ failed
                      ▼
┌─────────────────────────────────────────────────────┐
│ 2. Migration (ncc-migrate-config / migration.nix)   │
│    • v0→v1: extract fields, write config files,     │
│              delete system-config.nix, cleanup       │
│    • Already v1: pre-check cleans stale files only   │
└─────────────────────┬───────────────────────────────┘
                      │ done
                      ▼
┌─────────────────────────────────────────────────────┐
│ 3. User selects source (remote / local)             │
│    • Local: /home/<user>/Documents/Git/.../nixos    │
│    • Remote: GitHub branch                          │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│ 4. File Sync (system-update.nix sync logic)         │
│    • Copies core/, modules/, packages/, flake.nix   │
│    • Preserves systemConfig/, custom/, hardware-cfg │
│    • Template-config sync (v0→v1 only)              │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│ 5. Prebuild Checks (system-checks/)                 │
│    • CPU/GPU/Memory detection vs hardware-config    │
│    • User check (password existence)                │
│    • Each check WRITES to hardware-config.nix if    │
│      mismatch (inline, no external command dep)     │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│ 6. nixos-rebuild (ncc system build switch --flake)   │
│    • Builds new generation                           │
│    • Switches to it on success                       │
└─────────────────────────────────────────────────────┘
```

---

## Key File Relationships

### system-manager (the heart)
```
system-manager/
├── handlers/system-update.nix       # MAIN update orchestrator — imports configModule
├── components/config-migration/     # v0→v1 migration logic
│   ├── default.nix                  #   entry point, imports all subcomponents
│   ├── migration.nix                #   ncc-migrate-config script (BIG — 600+ lines)
│   ├── validator.nix                #   ncc-validate-config script
│   ├── detection.nix                #   ncc-detect-version script
│   ├── check.nix                    #   ncc-config-check (validator + migration wrapper)
│   ├── commands.nix                 #   registers config-check/detect/migrate/validate as ncc commands
│   ├── schema.nix                   #   version schema definitions
│   ├── schema/v0.nix, v1.nix        #   per-version field definitions
│   ├── schema/migrations/v0-to-v1.nix # migration plan (field mappings)
│   ├── types.nix, utils.nix         #   helpers
├── components/system-checks/        # prebuild hardware/user checks
│   └── prebuild/checks/hardware/
│       ├── cpu.nix                  #   CPU detection + writes hardware-config.nix
│       ├── gpu.nix                  #   GPU detection (nvidia, amd, intel, hybrid)
│       ├── memory.nix               #   RAM size detection (rounded to std sizes)
│       └── utils.nix                #   update-hardware-config script (for manual use only)
│   └── prebuild/checks/system/
│       └── users.nix                #   user check, password management
├── lib/
│   ├── config-loader.nix            #   recursive config discovery from systemConfig/
│   ├── backup-helpers.nix           #   backup functions
│   └── utils-config-migration.nix   #   migration chain helpers
├── config.nix                       #   system-manager module config
├── options.nix                      #   system-manager module options
└── commands.nix                     #   registers system-update, system build, etc. as ncc commands
```

### CLI System
```
cli-registry/lib/
├── types.nix             # command option types
├── registration.nix      # how commands register
├── validation.nix        # command validation
└── execution.nix         # command execution logic
```

### Module Loading Chain
```
flake.nix
  └─► config-loader.nix (discovers config.nix files from systemConfig/)
        └─► loads each config.nix
              └─► module-manager/lib/module-config.nix (merges template defaults + user config)
```

---

## Migration Components & What They Do

| Component | File | Purpose | Key Detail |
|-----------|------|---------|------------|
| migration.nix | `components/config-migration/migration.nix` | v0→v1 migration script | jq-based field extraction + system-config.nix deletion |
| validator.nix | `components/config-migration/validator.nix` | Validates config structure | Recursive config.nix validation, version detection |
| detection.nix | `components/config-migration/detection.nix` | Detects config version | Checks configVersion field or system-config.nix existence |
| check.nix | `components/config-migration/check.nix` | Wraps validator + migration | Runs validator → migration → re-validator |
| system-update.nix | `handlers/system-update.nix` | Full update orchestration | Syncs files, runs checks, builds |
| cpu.nix | `components/system-checks/.../cpu.nix` | CPU prebuild check | Inline hardware-config write |
| gpu.nix | `components/system-checks/.../gpu.nix` | GPU prebuild check | Detects nvidia/amd/intel/hybrid |
| memory.nix | `components/system-checks/.../memory.nix` | Memory prebuild check | Rounds to standard sizes (4/8/16/32/64/128) |
| users.nix | `components/system-checks/.../users.nix` | User prebuild check | Password management via openssl passwd -6 |
| config-loader.nix | `lib/config-loader.nix` | Config file discovery | Recursive find of config.nix + n-config.nix |

---

## Critical Patterns & Conventions

### Nix `''` String Escaping (CRITICAL for LLM)
Inside Nix indented strings (`''...''`):
- `${...}` = Nix interpolation
- `''${...}` = literal `${...}` in output (for bash variable references)
- `''` inside string = literal `'`

**Common mistake:** Writing `${SOME_BASH_VAR}` inside a Nix `''` string → Nix tries to interpolate it → fails.
**Fix:** Use `''${SOME_BASH_VAR}`.

### Prebuild Checks Don't Have `update-hardware-config`
The `update-hardware-config` script is defined in `utils.nix` and added to `environment.systemPackages`.
It only exists AFTER `nixos-rebuild switch`. The prebuild checks run BEFORE the build.
→ Each check script has INLINE bash functions (`_update_cpu`, `_update_gpu`, `_update_memory`) that write the hardware-config directly.

### Module Config Pattern
Each module follows:
```
module-name/
├── options.nix          # NixOS module options (the "API" of the module)
├── config.nix           # Module code (imported by flake.nix)
├── commands.nix         # CLI command registrations (optional)
├── n-config.nix         # Template/default config (copied to systemConfig/ on first install)
├── handlers/            # Script handlers (optional)
└── lib/                 # Helper functions (optional)
```

### Password Management in users.nix
Passwords are stored in `/etc/nixos/secrets/passwords/<user>/.hashedPassword`.
The prebuild check uses `openssl passwd -6 -stdin` to generate SHA-512 hashes,
saves them to `.hashedPassword`, and sets the system password via `chpasswd -e`.
This avoids the unreliable `passwd` + `grep /etc/shadow` pattern.

### Backup System
Backups go to `/var/backup/nixos/` with retention of 5 backups.
When `system-config.nix` is deleted during migration, it's backed up first.

---

## Platform-Specific Notes

- **build platform:** NixOS (obviously)
- **shell:** bash (scripts generated via pkgs.writeShellScriptBin / pkgs.writeScriptBin)
- **jq version:** must support recursive function definitions (jq 1.6+)
- **openssl available** at `${pkgs.openssl}/bin/openssl`
- **pciutils available** at `${pkgs.pciutils}/bin/lspci`
- **nix-instantiate** used for eval; `nix eval` also available in newer versions
- **paths:** `/etc/nixos/systemConfig/`, `/etc/nixos/system-config.nix`, `/etc/nixos/hardware-configuration.nix`

---

## Common Issues & Fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `build failed: syntax error, unexpected '='` | Unescaped `${VAR%pattern}` in Nix `''` string | Use `''${VAR%pattern}` |
| `update-hardware-config: command not found` | Prebuild check calls external cmd that doesn't exist yet | Check uses inline `_update_*` function now |
| `jq: error: formatValue/0 is not defined` | jq function called via pipe instead of direct arg | Use `formatValue($x)` not `$x \| formatValue` |
| `core/base/config.nix has invalid Nix syntax` | Aggregator config from v0 still exists | migration.nix deletes these in v1 cleanup |
