# NCC permissions SSOT — user leaf stays under /etc/nixos

## Storage

```text
/etc/nixos/systemConfig/
  core/base/user/config.nix     → account identity (role, shell, autoLogin)
  core/** … modules/**          → system (admin / restricted-admin)
  users/<name>/config.nix       → user leaf / packages (guest: only self; admins: any)
```

Do **not** move user config out of `/etc/nixos`. Isolation is **leaf + helper**, not a separate tree.

## Helper

- `ncc-priv` / `ncc-priv-run` (pkexec)
- `user-pkg add|remove` → only `users/<target>/config.nix` + `userPackages`
- `user-account create|set|delete` → only `core/base/user` account attrs (+ leaf seed/remove)
- Guests/virtualization: packages `target == invoker`; no account manage
- Admin / restricted-admin: account manage; packages any user
- Restricted-admin: cannot assign or create `admin`; cannot delete `admin`
- Cannot delete/demote the last `admin` / `restricted-admin`

## Rebuild

After writes, optional `--rebuild`. Elevation via helper; UI must not talk about pkexec/sudo.
`/etc/ncc/user-roles` is reseeded on activation and synced by the helper after account changes.

## Roles

| Role | Own packages | Other leaf | Create/set/delete users | Assign `admin` |
|------|--------------|------------|-------------------------|----------------|
| guest | yes | no | no | — |
| virtualization | yes (self) | no | no | — |
| restricted-admin | yes | yes | yes | no |
| admin | yes | yes | yes | yes |

CLI: `ncc user list|show|whoami|create|set|delete`  
See also: `user/api.nix` capabilities.
