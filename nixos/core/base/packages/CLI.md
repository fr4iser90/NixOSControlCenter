# CLI — packages

> SSOT: [STANDARDS](../../management/cli-formatter/doc/STANDARDS.md) · [COPY](../../management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc packages` | Package management entry / help | N/A | no |
| `ncc packages add\|remove\|list` | Single nixpkgs packages | no | system: yes |
| `ncc packages search\|resolve\|try\|categories` | Store intents | N/A | no |
| `ncc packages module …` | Sets / presets | no | system sets: yes |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in shipped scripts (`ncc-packages.nix` log_* via `ui.colors` / badge style)
- [x] No local colors / `echo -e` / ANSI in package CLI logging
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [ ] Dry-run documented or N/A
- [ ] README links here

## Notes

- Machine JSON (`--json`) and raw list/search tables stay uncolored.
- Dynamic `log_*` helpers use formatter palette + `[INFO]` / `[ OK ]` / `[WARN]` / `[ERROR]`.
