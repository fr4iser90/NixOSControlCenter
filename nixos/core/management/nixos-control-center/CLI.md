# CLI — nixos-control-center

> SSOT: [STANDARDS](../cli-formatter/doc/STANDARDS.md) · [COPY](../cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc-priv` / `ncc-priv-run` | Privileged user-pkg + account writes | no | yes (pkexec/sudo) |
| `ncc-priv-security-tests` | Policy self-tests | N/A | no |
| `ncc-hello` | Example stub package | N/A | no |

## Self-audit

- [x] `getModuleApi "cli-formatter"` in `config.nix` API + `privileged-helper.nix`
- [x] Privileged OK/error/permission status via `ui.messages`
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [x] Dry-run documented or N/A
- [ ] README links here

## Notes

Facade API exposes `formatter` to peers. Security-test PASS/FAIL lines stay plain for grep. Docs under `*.md` may still use emoji checklists (not CLI status).
