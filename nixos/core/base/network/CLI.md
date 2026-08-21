# CLI — network

> SSOT: [STANDARDS](../../management/cli-formatter/doc/STANDARDS.md) · [COPY](../../management/cli-formatter/doc/COPY.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc network` | Help / `--gui` / `--tui` | N/A | no |
| `ncc network status [--json]` | Link summary (`key=value`) | N/A | no |
| `ncc network wifi …` | Scan / list / connect / forget / radio | yes on connect/disconnect/forget | connect/forget: yes |
| `ncc network ethernet …` | Status / disconnect / reconnect | yes on disconnect/reconnect | mutate: yes |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in wifi + ethernet + status scripts
- [x] Header (skipped when `NCC_CLI_NESTED=1`)
- [x] `--dry-run` on wifi connect/disconnect/forget and ethernet disconnect/reconnect
- [x] Loading / facts / success|error / Next (nested-aware)
- [x] No private ANSI / `ui.colors` printf for user lines
- [x] Verbose detail gated with `-v` where applicable (short / machine surfaces OK)
- [x] `longHelp` matches COPY tone
- [x] README links here

## Notes

`status` / `--json` and nmcli table dumps stay raw under formatter chrome.
Radio on/off are short mutates without dry-run (toggle only).
