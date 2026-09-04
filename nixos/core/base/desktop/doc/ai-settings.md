# Domain: desktop

## Tools

| Tool | Risk | Who |
|------|------|-----|
| `domain.desktop.status` | read | everyone (`desktop.read`) |
| `domain.desktop.set` | write | admin, restricted-admin (`desktop.set`) |

## Rules

- Prefer `domain.desktop.status` before changing anything.
- `domain.desktop.set` writes **systemConfig only** (no `--rebuild`). Tell the user a rebuild is still required.
- Valid values: environment `plasma|gnome|xfce|hyprland`, manager `sddm|gdm|lightdm`, server `wayland|x11|hybrid`, dark `true|false`.
- Pass only fields that should change (optional args).
