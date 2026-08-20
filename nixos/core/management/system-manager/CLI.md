# CLI — system-manager

> SSOT: [STANDARDS](../cli-formatter/doc/STANDARDS.md) · [COPY](../cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands (high traffic)

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc system update` | Sync tree from local/remote + merge host flake extras | `--dry-run` / `-d` | yes (except dry-run) |
| `ncc system update-modules` | Module tree update | `--dry-run` | yes |
| `ncc system migrate-config` | Schema / platform heal | via `ncc-config-check --dry-run` | yes |
| `ncc-config-check` | Validate (+ migrate unless dry-run) | `--dry-run` | no for dry-run |
| `ncc system build …` | rebuild/switch | N/A | yes |

## How update should look

See [STANDARDS §4](../cli-formatter/doc/STANDARDS.md).

Quick validate:

```bash
ncc system update --dry-run --local --source-dir /path/to/NixOSControlCenter/nixos
ncc system update --dry-run -v --local --source-dir /path/to/NixOSControlCenter/nixos
```

## Self-audit

- [x] `system-update.nix` uses `ui.messages` / headers / dry-run / `-v` gating for extras
- [x] `config-migration/check.nix` supports `--dry-run` (no writes)
- [x] Host flake extras merge + preview path
- [x] `enable-desktop.nix` wired to `ui.messages`
- [x] `postbuild-checks.nix` uses `ui.messages` / `ui.badges` (no private ANSI)
- [ ] Full pass: channel-manager copy, migration.nix verbosity, allow-unfree copy
- [ ] Replace remaining raw `echo` dumps with `-v` gates
- [ ] README links here

## Validate (automated)

```bash
bash tests/cli-formatter/validate-cli.sh
```

Details: [tests/cli-formatter/MANUAL.md](../../../../tests/cli-formatter/MANUAL.md) — what is automatic vs live-host smoke.
- Preview: `/tmp/ncc-flake-update-preview.nix`
- Backup path shown only with `-v`
