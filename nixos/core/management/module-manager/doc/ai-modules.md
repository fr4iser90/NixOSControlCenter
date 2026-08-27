# Domain: modules

## Tools

| Tool | Risk | Who |
|------|------|-----|
| `domain.modules.list` | read | admin, restricted-admin (`module.read`) |
| `domain.modules.show` | read | admin, restricted-admin (`module.read`) |
| `domain.modules.enable` | write | admin, restricted-admin (`module.enable`) |
| `domain.modules.disable` | write | admin, restricted-admin (`module.disable`) |

## Rules

- Core modules cannot be disabled; do not invent workarounds.
- enable/disable write **systemConfig** only — omit rebuild flags; tell the user to rebuild via the normal flow.
- Use `list` / `show` before enable/disable. Prefer module **name** as shown by list.
- Guests cannot manage modules.
