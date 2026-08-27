# Domain: packages

## Tools

| Tool | Risk | Permission |
|------|------|------------|
| `domain.packages.list` | read | `package.user.self` |
| `domain.packages.add` | write | `package.user.self` |
| `domain.packages.remove` | write | `package.user.self` |
| `domain.packages.module_list` | read | `package.user.self` |
| `domain.packages.module_available` | read | `package.user.self` |
| `domain.packages.module_info` | read | `package.user.self` |
| `domain.packages.module_add` | write | `package.user.self` |
| `domain.packages.module_remove` | write | `package.user.self` |

## Rules

- Default scope is the **current user’s** `userPackages`. Set `system=true` only for global `systemPackages` / system presets (needs admin or restricted-admin; enforced by `ncc-priv`).
- Always use `--no-build` from these tools. Tell the user a rebuild is still required for packages to become active.
- Prefer `module_available` / `module_info` before enabling sets or presets.
- User presets (names like `user-…`) write that user’s packages; system presets/sets write `packageModules`.
- Do not invent package names — if unsure, list or ask.
