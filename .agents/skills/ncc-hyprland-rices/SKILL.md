---
name: ncc-hyprland-rices
description: >-
  Work on NCC Hyprland rice catalog, Hall of Fame previews, NCC-Hyperland-Collection
  apply store, install/validate/verify, and collection-pin updates. Use when editing
  hyprland rice-catalog, rice install, wallpaper, or the Hyperland Collection repo.
---

# NCC Hyprland rices

## Two catalogs (do not mix)

| Source | Role |
|--------|------|
| `nixos/core/base/hyprland/lib/rice-catalog-hof.nix` | Hall of Fame **gallery** — mostly `applyMethod = "reference"` (preview) |
| **`NCC-Hyperland-Collection`** | Apply store — real installable rices (`dotfiles` / `flake` / …) |

Merge: `lib/rice-catalog.nix` = `hof // collectionRices` (collection wins on id clash).

## Collection resolve

1. Sibling checkout: `Documents/Git/NCC-Hyperland-Collection` (if `nix/catalog.nix` exists)
2. Else pinned GitHub: `lib/collection-pin.nix` → `fr4iser90/NCC-Hyperland-Collection`

After pushing collection changes, bump `rev` + `hash` in `collection-pin.nix`.

## Apply paths (host)

- Collections: `/var/lib/ncc/hyprland/collections/<id>/` (on-demand clone — not `~/`)
- CLI: `ncc hyprland rice list|info|install|validate|verify`
- Set: `sudo ncc hyprland set enable=true rice=<id>`

Docs: `nixos/core/base/hyprland/doc/usage.md`, `doc/architecture.md`.

## Agent constraints

- Edit **git** trees (NCC and/or Collection). Do not poke live `/etc/nixos` or `/var/lib/ncc` unless the user pastes paths/output.
- After `nixos/core/base/hyprland/**` changes: `bash tests/run-gates.sh`.
