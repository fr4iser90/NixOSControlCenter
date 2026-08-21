# CLI — packages

> SSOT: [STANDARDS](../../management/cli-formatter/doc/STANDARDS.md) · [COPY](../../management/cli-formatter/doc/COPY.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc packages` | Package management entry / help | N/A | no |
| `ncc packages add\|remove\|list` | Single nixpkgs packages | yes (`--dry-run` on mutate) | system: yes (skipped on dry-run) |
| `ncc packages search\|resolve\|try\|categories` | Store intents | N/A | no |
| `ncc packages module …` | Sets / presets | yes (`--dry-run` on add/remove) | system sets: yes (skipped on dry-run) |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` — user lines via `ui.messages` / `ui.text.header` / `ui.tables`
- [x] Header (skipped when `NCC_CLI_NESTED=1`)
- [x] `--dry-run` on `add` / `remove` / `module add` / `module remove`: banner + preview, no writes, Next
- [x] Loading + short facts; `--verbose` gates paths/layout
- [x] success|warning|error via `ui.messages` (no custom `log_*`)
- [x] Next hints on success / actionable failure (skipped when nested)
- [x] No local colors / `echo -e` / ANSI for user status
- [x] `longHelp` matches COPY tone
- [x] README links here

## Notes

- Machine JSON (`--json`) skips human chrome.
- **`-v` / `--version`** show version. Use **`--verbose`** for technical detail (not `-v`).
- Dry-run skips `ncc-priv` / config flush / rebuild prompt.
