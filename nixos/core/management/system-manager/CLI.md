# CLI — system-manager

> SSOT: [STANDARDS](../cli-formatter/doc/STANDARDS.md) · [COPY](../cli-formatter/doc/COPY.md)

**Status:** `compliant`

## Commands (high traffic)

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc system update` | Sync tree from local/remote + merge host flake extras | `--dry-run` / `-d` | yes (except dry-run) |
| `ncc system update-modules` | Module tree update | `--dry-run` | yes |
| `ncc system migrate-config` | Schema / platform heal | via `ncc-config-check --dry-run` | yes |
| `ncc-config-check` | Validate (+ migrate unless dry-run) | `--dry-run` | no for dry-run |
| `ncc system build …` | rebuild/switch | N/A | yes |

## How update should look

See [STANDARDS §4](../cli-formatter/doc/STANDARDS.md) — **default = `[ OK ]` checklist**, **`-v` = details + rebuild noise**.

```bash
ncc system update --local                    # short checklist
ncc system update --local -v                 # + copy steps + nixos-rebuild log
ncc system update --dry-run --local --source-dir /path/to/nixos
```

## Self-audit

- [x] Skeleton on main paths: **one** header → work → result (honors `NCC_CLI_NESTED` / `NCC_QUIET_SWITCH`)
- [x] No mid-flow `=== Build ===` / `--- Preflight ---` / activation System Report under update
- [x] No duplicate `Next: reboot…` after successful update+build
- [x] `config-migration/check.nix` supports `--dry-run` (no writes)
- [x] Host flake extras merge + preview path
- [x] cli-registry preserves `NCC_CLI_NESTED` / `NCC_QUIET_SWITCH` through sudo
- [x] README links here

## Notes

`migration.nix` still uses raw `echo`/`printf` for **config file writes and internal jq plumbing** — not user-facing status lines.
Activation System Report is **off by default** (env does not reach activation). Full dump: `ncc system report`, or `NCC_SYSTEM_REPORT=1` before a bare switch.

## Validate (automated)

```bash
bash tests/cli-formatter/validate-cli.sh
```

Details: [tests/cli-formatter/MANUAL.md](../../../../tests/cli-formatter/MANUAL.md) — what is automatic vs live-host smoke.
- Preview: `/tmp/ncc-flake-update-preview.nix`
- Backup path shown only with `-v`
