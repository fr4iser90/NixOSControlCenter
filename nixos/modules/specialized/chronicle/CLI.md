# CLI — chronicle

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc chronicle` | Record / status / list / cleanup | N/A (no live `/etc/nixos` writes) | no |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in main script + utils / error-handling / cloud / email / integrations log helpers
- [x] Main `ncc chronicle` entry (`scripts/main.nix`): header → loading → result → `Next:` (honors `NCC_CLI_NESTED=1`)
- [x] Badge-style log helpers in `lib/utils.nix`
- [x] Secondary surfaces plain status (no emoji / `echo -e`): plugins, AI, collaboration, visualization, export-all, themes, notifications, audio-commentary, search/comparison
- [x] README links here

## Notes

Secondary helpers without `getModuleApi` use plain text; entry path + utils/error-handling/cloud/email/integrations use `ui.messages`.
