# Chronicle - Rename History

## Module Renamed: step-recorder → chronicle

**Date:** January 2, 2026  
**Version:** v4.0.0

---

## Why "Chronicle"?

The module has evolved far beyond a simple "step recorder." With enterprise features, AI integration, compliance tools, and collaboration capabilities, the name needed to reflect its true purpose:

> **Chronicle is your digital work memory** - recording, documenting, and analyzing workflows to create knowledge, provide evidence, and enable automation.

---

## What Changed

### Technical Renames

All references throughout the module have been updated:

#### Commands
- `step-recorder` → `chronicle`
- `step-recorder-api` → `chronicle-api`
- `step-recorder-github` → `chronicle github`
- All subcommands now follow `chronicle <action>` pattern

#### Configuration Paths
- `systemConfig.modules.specialized.step-recorder` → `systemConfig.modules.specialized.chronicle`

#### Environment Variables
- `STEP_RECORDER_*` → `CHRONICLE_*`
  - `CHRONICLE_OUTPUT_DIR`
  - `CHRONICLE_FORMAT`
  - `CHRONICLE_API_HOST`
  - `CHRONICLE_API_PORT`

#### File Paths
- `~/.local/share/step-recorder` → `~/.local/share/chronicle`
- `~/.config/nixos-step-recorder` → `~/.config/nixos-chronicle`
- `~/.local/state/nixos-step-recorder` → `~/.local/state/nixos-chronicle`
- `/tmp/step-recorder-*` → `/tmp/chronicle-*`

#### Systemd Services
- `step-recorder.service` → `chronicle.service`
- `step-recorder-api.service` → `chronicle-api.service`

#### Internal Variables
- `stepRecorderLib` → `chronicleLib`
- `stepRecorder` → `chronicle` (where appropriate)

---

## Migration for Users

### For New Users
Simply use `chronicle` - everything works out of the box!

### For Existing Users

If you were using the old `step-recorder` module:

#### 1. Update Configuration

**Old:**
```nix
systemConfig.modules.specialized.step-recorder = {
  enable = true;
  # ... your settings
};
```

**New:**
```nix
systemConfig.modules.specialized.chronicle = {
  enable = true;
  # ... your settings (unchanged)
};
```

#### 2. Update Commands

**Old Commands:**
```bash
step-recorder start
step-recorder-api
step-recorder-github create-auto
```

**New Commands:**
```bash
chronicle start
chronicle-api
chronicle github create-auto
```

#### 3. Migrate Data (Optional)

Your old recordings are safe! If you want to migrate them:

```bash
# Migrate recordings
mv ~/.local/share/step-recorder ~/.local/share/chronicle

# Migrate config
mv ~/.config/nixos-step-recorder ~/.config/nixos-chronicle

# Migrate state
mv ~/.local/state/nixos-step-recorder ~/.local/state/nixos-chronicle
```

Or keep them separate if you prefer!

#### 4. Update Scripts/Aliases

If you have any shell scripts or aliases using `step-recorder`, update them to use `chronicle`.

---

## Files Changed

**Total files processed:** 109

### Core Module Files
- `default.nix` - Module metadata and description
- `options.nix` - Configuration options
- `commands.nix` - Command registry
- `config.nix` - System configuration
- `systemd.nix` - Systemd services

### All Subdirectories
- `lib/` - Core libraries (21 files)
- `scripts/` - Main scripts
- `handlers/` - Recording and export handlers
- `formatters/` - HTML, Markdown, JSON, PDF exporters
- `backends/` - X11 and Wayland backends
- `api/` - REST API server
- `integrations/` - GitHub, GitLab, JIRA, ServiceNow, Salesforce
- `cloud/` - S3, Nextcloud, Dropbox
- `email/` - SMTP integration
- `analysis/` - Performance metrics, system logs, file changes
- `search/` - Full-text search and comparison
- `privacy/` - Face blur, OCR redaction, encryption
- `compliance/` - GDPR, HIPAA
- `security/` - RBAC, sandboxing, validation
- `ai/` - LLM integration, anomaly detection, pattern recognition
- `collaboration/` - Real-time sharing
- `visualization/` - Heatmaps
- `plugins/` - Plugin system
- `enterprise/` - Multi-tenancy, SSO, Kubernetes
- `mobile/` - Android and iOS
- `platforms/` - Windows and macOS
- `gui/` - GTK4 app and system tray

### Documentation Files
- `ROADMAP.md`
- `CHANGELOG.md`
- `V1.1.0_RELEASE.md`
- `V1.2.0_RELEASE.md`
- `V2.0.0_RELEASE.md`
- `v2.5.0_RELEASE.md`
- `v3.0.0_RELEASE.md`
- `v4.0.0_RELEASE.md`
- `api/README.md`

---

## Backward Compatibility

**Breaking Changes:** Yes - this is a breaking change requiring user action.

**Why no compatibility layer?**
- Clean break allows for better long-term maintainability
- The project is in active development (v4.0.0)
- Better to break once cleanly than maintain dual names forever

---

## Backup

A full backup of all modified files was created at:
```
nixos/modules/specialized/chronicle/.backup-20260201_162722/
```

You can restore any file if needed, or delete the backup once verified:
```bash
rm -rf /home/fr4iser/Documents/Git/NixOSControlCenter/nixos/modules/specialized/chronicle/.backup-20260201_162722
```

---

## Verification

To verify the rename was successful:

```bash
cd nixos/modules/specialized/chronicle

# Should return 0 (no old references)
grep -r "step-recorder" --include="*.nix" --include="*.sh" --exclude-dir=".backup-*" . | wc -l

# Should return many results (new name everywhere)
grep -r "chronicle" --include="*.nix" --include="*.sh" --exclude-dir=".backup-*" . | wc -l
```

---

## Questions?

- **Issue Tracker:** https://github.com/fr4iser90/NixOSControlCenter/issues
- **Documentation:** See `ROADMAP.md` for feature overview
- **Support:** Check `api/README.md` for API documentation

---

**Welcome to Chronicle - Your Digital Work Memory! 🎯**
