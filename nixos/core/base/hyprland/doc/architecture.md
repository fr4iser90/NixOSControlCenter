# Hyprland module architecture (NCC)

## Catalogs (two layers)

1. **Hall of Fame** (`lib/rice-catalog-hof.nix`) — preview / reference metadata from
   https://hypr.land/hall_of_fame/ (not applyable by itself)
2. **NCC-Hyperland-Collection** — applyable catalog only (links + packages + notes;
   **no** vendored upstream dots). Repo:
   https://github.com/fr4iser90/NCC-Hyperland-Collection

Merged in `lib/rice-catalog.nix` (`hof // collection`; collection wins on id).

## One-to-one gallery look

Apply must mean **full-stack fidelity** (bar, wallpaper, fonts, autostart—not Hypr
config alone). See **[one-to-one-rice-plan.md](./one-to-one-rice-plan.md)** for the
complete target model, recipe schema, installer/validate changes, and phased plan.

Until a rice has `fidelity = "full"` + `validated100`, treat it as incomplete;
do not market Hypr-only deploys as Hall of Fame one-clicks.

## applyMethod

| Method | Meaning |
|--------|---------|
| `dotfiles` | Collection entry — clone upstream at install |
| `flake` | Dotfiles + host flake patch (rare; must still pass validate) |
| `wallpaper` | Wallpaper only |
| `reference` | HoF gallery / not applyable |

## Data flow

```
rice-catalog-hof.nix ──┐
                       ├── rice-catalog.nix → mk-catalog-json.nix → CLI / GUI
collection catalog.nix ┘
                              ↓
                     rice install → sanitize → verify → activate
```

## Adding an applyable rice

1. Follow [one-to-one-rice-plan.md](./one-to-one-rice-plan.md) (full recipe)
2. `ncc hyprland rice validate <id>` → `validated100=YES`
3. Add entry under NCC-Hyperland-Collection `nix/rices/` + `nix/catalog.nix`
4. Document author section in that repo’s README
5. Bump `lib/collection-pin.nix` (or use sibling checkout)
6. Keep HoF entry as `reference` for gallery
