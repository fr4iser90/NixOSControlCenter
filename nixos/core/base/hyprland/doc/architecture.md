# Hyprland module — architecture

## Overview

1. **Rice catalog** — SSOT in `lib/rice-catalog.nix` (Hall of Fame metadata)
2. **Collections** — upstream dotfiles fetched on install to `/var/lib/ncc/hyprland/collections/<id>/`
3. **Apply** — `ncc hyprland set` writes systemConfig + runs `rice install`
4. **Activation** — switch generates `/etc/xdg/hypr/hyprland.conf` from collection + hyprpaper header

## applyMethod

| Value | Store | Install |
|-------|-------|---------|
| `dotfiles` | yes | git clone + hypr config discover |
| `flake` | yes | dotfiles fetch + patch `flake.nix` markers |
| `wallpaper` | yes | wallpaper fetchurl only |
| `reference` | no | metadata only |

## Data flow

```
rice-catalog.nix → mk-catalog-json.nix → CLI / GUI
                 → hyprland-set → systemConfig
                 → hyprland-rice-install → /var/lib/ncc/hyprland/
                 → config.nix activation → /etc/xdg/hypr/hyprland.conf
```

## Flake patch markers

Host `flake.nix` contains:

- `# ncc-hyprland-rice-inputs-begin` … `end`
- `# ncc-hyprland-rice-modules-begin` … `end`

Patched by `lib/flake-rice-patch.py` when a flake-backed rice is installed.

## Adding rices

1. Add entry to `lib/rice-catalog.nix` with `df` / `fk` helper
2. Set real `thumbnailHash` (`nix hash file` after download)
3. Run `bash tests/run-gates.sh`
