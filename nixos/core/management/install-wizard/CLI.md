# CLI — install-wizard

> SSOT: [STANDARDS](../cli-formatter/doc/STANDARDS.md) · [COPY](../cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc install …` | Guided install | yes (`dry-run`) | varies |

## Self-audit

- [x] `colors.sh` generated from `getModuleApi "cli-formatter"`
- [x] `logging.sh` / `utils.sh` use formatter palette + badge-style tags
- [x] Preview scripts use `$BLUE`/`$BOLD` from colors.sh (no private palette)
- [ ] Full COPY pass on every install step message
- [ ] README links here

## Notes

Script tree packaging passes `getModuleApi` into all script nix files.
