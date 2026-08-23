# CLI — ssh-manager client

> SSOT: [STANDARDS](../../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc ssh client` | Interactive connection manager | N/A | no |
| `ncc ssh client --tui\|--gui` | TUI / domain GUI | N/A | no |
| `ncc ssh client list\|add\|edit\|delete\|connect` | Direct actions | N/A | no |

Display aliases (optional) are stored in `~/.config/ncc/ssh-host-labels.json`
(keyed by `user@host`). Edit them in the SSH GUI or Target “+ / edit” dialogs.
Connect identity remains `user@host` / `~/.creds`.

## Output contract

- Mutating verbs (`add` / `edit` / `delete` / `connect`): header → loading → success/error → `Next:`
- Interactive entry (`ncc ssh client`): header → loading → fzf → work → result → `Next:` on mutate/cancel
- `list`: machine `host=user` lines (intentional)
- `NCC_CLI_NESTED=1` skips header / next
- Go BubbleTea TUI (`--tui`): separate binary — formatter out of scope (same as other domain TUIs)

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in main / keys / remote-hosts / handlers
- [x] add / edit / delete / connect follow §3 skeleton
- [x] Interactive fzf entry follows §3 skeleton
- [x] Dry-run N/A (documented)
- [ ] Go TUI full formatter redesign — out of scope (separate binary)
- [x] README links here

## Notes

Compliant covers shell CLI verbs + interactive fzf entry. Parent `ssh-manager` CLI.md is `compliant` for server verbs.
