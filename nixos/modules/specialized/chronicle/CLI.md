# CLI — chronicle

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc chronicle` | Record / status / list / cleanup | N/A | no |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in main script + utils / error-handling / cloud / email / integrations log helpers
- [ ] No local colors / `echo -e` / ANSI (plugins, AI, notifications, export-all still emoji)
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [ ] Dry-run documented or N/A
- [ ] README links here

## Notes

Priority path migrated: `lib/utils.nix`, `lib/error-handling.nix`, `scripts/main.nix`, cloud/*, integrations/{github,gitlab,jira}, email/smtp.
