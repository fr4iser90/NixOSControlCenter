# Hyprland — usage

## Enable

```nix
core.base.desktop = {
  enable = true;
  environment = "hyprland";
  display.manager = "sddm";
  display.server = "wayland";
  display.session = "hyprland";
};

core.base.hyprland = {
  enable = true;
  rice = "astroland";
};
```

## One-liner apply

```bash
sudo ncc hyprland set enable=true rice=astroland --rebuild
```

This writes `systemConfig`, fetches dotfiles to `/var/lib/ncc/hyprland/collections/<id>/`, and rebuilds.

## GUI store

```bash
ncc hyprland --gui
```

Select a rice → **Apply selected** → **Rebuild**. Previews use bundled contest thumbnails.

## Apply methods

| Method | On install | Hypr config source |
|--------|------------|-------------------|
| **dotfiles** | `git clone` → `/var/lib/ncc/hyprland/collections/<id>/` | Upstream `hyprland.conf` via activation |
| **flake** | dotfiles fetch + `flake.nix` input/module patch | Upstream config + optional `nixosModules` |
| **wallpaper** | wallpaper hash only | Generated minimal config + hyprpaper |

Nothing is cloned into `~/`. Collections are on-demand only.

## CLI

```bash
ncc hyprland rice list
ncc hyprland rice list --all
ncc hyprland rice info celestial
sudo ncc hyprland rice install astroland
sudo ncc hyprland rice install --from-set
ncc hyprland status
```

## Paths

- Collections: `/var/lib/ncc/hyprland/collections/<rice-id>/upstream/`
- Active manifest: `/var/lib/ncc/hyprland/active.json`
- Live hypr config: `/etc/xdg/hypr/hyprland.conf` (generated on switch)
