# NCC permissions SSOT — user config stays under /etc/nixos

## Storage

**Monolith** (preferred default): single file only — no `systemConfig/` tree.

```text
/etc/nixos/systemConfig.nix
  core.base.user.<name>     → account identity (role, shell, autoLogin)
  users.<name>              → user leaf / packages
  core.** / modules.**      → system modules
```

Migration plan state: `/var/lib/ncc/module-migrations.json` (not under `/etc/nixos`).

**Split**:

```text
/etc/nixos/systemConfig/
  core/base/user/config.nix     → account identity
  core/** … modules/**          → system (admin / restricted-admin)
  users/<name>/config.nix       → user leaf / packages
```

Do **not** keep a hybrid (`systemConfig.nix` + leftover `systemConfig/users/`). Scrub on update / `ncc config-layout convert --to monolith`.

## Helper

- `ncc-priv` / `ncc-priv-run` (pkexec)
- `user-pkg add|remove` → logical path `users/<target>` (`userPackages`); split writes a leaf file, monolith merges into `systemConfig.nix`
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

## Packages GUI

| Area | guest / virt | admin / restricted-admin |
|------|--------------|--------------------------|
| My packages (leaf) | read + write self | read + write |
| System sets (`packageModules`) | read only | read + write |
| System packages | hidden | read + write |

Multi-select + batch Add/Remove. Elevation: user leaf via `ncc-priv-run`; system via kit `run_ncc_root` (sudo -n first).
