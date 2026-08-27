# CLI — boot

> SSOT: [STANDARDS](../../management/cli-formatter/doc/standards.md) · [COPY](../../management/cli-formatter/doc/copy.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| _(none)_ | Config / NixOS options only — no `ncc boot` CLI | N/A | N/A |

## Self-audit

- [x] No shipped CLI scripts with user-facing status
- [x] No local colors / `echo -e` / ANSI in module scripts
- [x] Dry-run documented or N/A
- [x] README links here

## Notes

Bootloader handlers (systemd-boot / GRUB / rEFInd) only. No CLI chrome to migrate.
