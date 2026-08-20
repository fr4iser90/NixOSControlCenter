# CLI — nixify

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc nixify` | Service + ISO build | N/A | service/ISO vary |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in `commands.nix` status messages
- [ ] No local colors / `echo -e` / ANSI (`iso-builder/validate-and-build.sh`, debug scripts, scan.sh still raw)
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [ ] Dry-run documented or N/A
- [ ] README links here

## Notes

`validate-and-build.sh` is a standalone bash helper (no Nix wrapper yet) — left as a gap.
