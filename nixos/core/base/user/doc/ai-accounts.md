# Domain: user (accounts)

Use these tools for account questions. Prefer tools over guessing config paths.

## Tools

| Tool | Risk | Who |
|------|------|-----|
| `domain.user.whoami` | read | everyone |
| `domain.user.list` | read | everyone (guests only see self) |
| `domain.user.show` | read | everyone (guests only self) |
| `domain.user.create` | write | admin, restricted-admin |
| `domain.user.set` | write | admin, restricted-admin |
| `domain.user.delete` | write | admin, restricted-admin |

## Rules

- Create/set/delete write **systemConfig only** (no rebuild). Tell the user a rebuild is still required for the account to exist on the live system — use the normal Apply/rebuild flow, do not invent `nixos-rebuild` via shell.
- **Guest / virtualization** must not create or promote accounts. If they ask, explain they lack permission.
- **restricted-admin** must not assign role `admin` (enforced by `ncc-priv`).
- Never invent passwords in tools (password flow is separate / interactive).
- Roles: `admin` | `restricted-admin` | `virtualization` | `guest`.
