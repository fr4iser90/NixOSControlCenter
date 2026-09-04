# One-to-one Hall of Fame look — plan

**Goal:** An applyable rice in NCC must match the Hall of Fame gallery look
(same compositor config, bars/shell, launcher, wallpaper, fonts, cursors, and
autostart stack)—not a bare Hyprland config with a few packages.

If we cannot prove that stack, the rice stays **preview / reference only**.
Shipping “Apply” for Hypr-only deploys is misleading.

---

## Current state (honest)

| Layer | Today |
|-------|--------|
| HoF catalog | Preview gallery (`rice-catalog-hof.nix`) |
| Collection | Apply metadata + links ([NCC-Hyperland-Collection](https://github.com/fr4iser90/NCC-Hyperland-Collection)) |
| Install | Clone upstream → sanitize → deploy **Hypr tree** to `/etc/xdg/hypr/` |
| Packages | Module defaults (waybar/hyprpaper) + `requiredPackages` from catalog |
| Validate | `validated100`: verify-config + mapped bins + no `/home` hardcodes |

**Gap:** Contest rices are full desktops (Waybar/AGS/Quickshell/Flutter, themes,
assets, scripts). NCC does not yet install that full stack → look ≠ gallery.

---

## Target model

```
Author repo (GitHub/Codeberg)     NCC-Hyperland-Collection
─────────────────────────────     ────────────────────────
hypr/, waybar/, assets, …   →     rice recipe (metadata only):
                                  - cloneUrl + ref
                                  - path map (what → where)
                                  - requiredPackages / fonts
                                  - wallpapers (url + hash)
                                  - rewrites / patches
                                  - autostart contract
                                           │
                                           ▼
                                  ncc hyprland set rice=<id>
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    ▼                      ▼                      ▼
              1. clone upstream     2. fetch assets        3. install pkgs
              4. rewrite paths      5. deploy full stack   6. verify-config
              7. validate100        8. nixos switch        9. Hyprland session
                                           │
                                           ▼
                                  Gallery-equivalent look
```

**Roles**

| Piece | Role |
|-------|------|
| Upstream repo | Material (configs/scripts; not vendored in Collection) |
| Collection recipe | Blueprint (links, packages, path map, assets, attribution) |
| NCC hyprland module | Builder (clone, sanitize, install, deploy, gate) |
| `validated100` | Acceptance test for 1:1 apply |

---

## Recipe schema (Collection — target)

Per rice under `nix/rices/<id>.nix` (evolve beyond today’s fields):

```nix
{
  id = "moon-rice";
  # … existing identity / thumbnail / upstream attribution …

  applyMethod = "dotfiles";
  fidelity = "full";   # "full" = 1:1 apply; never ship apply without this

  dotfiles = {
    cloneUrl = "https://github.com/…/*.git";
    ref = "main";
    hyprCandidates = [ /* … */ ];
  };

  # What to install from the clone (relative → NCC destination)
  deploy = [
    { from = "dots/hyprland.conf"; to = "hypr"; }       # → /etc/xdg/hypr/
    { from = "config/waybar";      to = "waybar"; }     # → /etc/xdg/waybar/ or state dir
    { from = "config/wofi";        to = "wofi"; }
    # …
  ];

  requiredPackages = [ "foot" "mako" "waybar" /* full stack */ ];
  fonts = [ "nerd-fonts.jetbrains-mono" /* nixpkgs attrs */ ];
  cursorTheme = { package = "bibata-cursors"; name = "Bibata-Modern-Ice"; size = 24; };

  wallpapers = [
    { url = "https://…"; hash = "sha256-…"; # rewrite config to this store path
      assign = [ "," ]; }
  ];

  # Optional: lines/scripts NCC appends after rewrite
  rewrites = [ /* documented path substitutions */ ];

  ncc = {
    validated100 = true;
    notes = "…";
  };

  upstream = {
    repo = "https://…";
    readme = "https://…";
    license = "See upstream (often no LICENSE file — all rights author)";
    hallOfFame = "https://hypr.land/hall_of_fame/";
  };
}
```

**Rules**

- Collection stores **recipes + attribution**, not full upstream trees.
- `fidelity = "full"` requires complete `deploy` + `requiredPackages` + assets.
- No `/home/<author>/…` or foreign `/nix/store/…` left after sanitize.

---

## NCC installer changes (target)

Today: Hypr-only rsync.  
**1:1 installer must:**

1. Clone `dotfiles.cloneUrl` @ `ref`
2. Run sanitize + verify-config repair (existing)
3. Resolve `requiredPackages` / fonts / cursor into `systemPackages` (+ fontconfig)
4. Fetch `wallpapers[]` via `fetchurl` and rewrite config references
5. Deploy every `deploy[]` entry to fixed NCC destinations
6. Scan **autostart scripts** (not only `hyprland.conf`) for binaries → fail validate if unmapped
7. Refuse install if `validated100` / `fidelity` gate fails
8. Activation: Hypr entry + companion configs available to the session

Suggested state layout:

```
/var/lib/ncc/hyprland/collections/<id>/upstream/   # clone
/var/lib/ncc/hyprland/collections/<id>/assets/     # fetched wallpapers etc.
/etc/xdg/hypr/                                     # active hypr tree
/etc/xdg/waybar/ …                                 # or NCC-owned xdg roots
```

---

## Validation gate (1:1)

`ncc hyprland rice validate <id>` must require **all** of:

1. Clone + hypr entry discovered  
2. NCC deploy simulation of **full** `deploy[]` map  
3. `hyprland --verify-config` OK on deployed hypr  
4. Every exec/autostart binary on PATH **or** in nixpkgs map → `requiredPackages`  
5. Autostart scripts scanned recursively  
6. No leftover author home paths  
7. Every wallpaper/asset in the recipe fetchable (hash)  
8. Recipe declares `fidelity = "full"`  

Exit 0 / `validated100=YES` only then.  
GUI / `ncc hyprland set` must not stage apply without that.

Live pre-login check remains: `ncc hyprland rice verify`.

---

## Product rules (anti-misleading)

| Store label | Meaning |
|-------------|---------|
| **Apply (1:1)** | Collection rice, `fidelity=full`, `validated100` |
| **Preview only** | HoF gallery / incomplete stack |

- Do **not** show incomplete Hypr-only deploys as one-click gallery rices.
- moon-rice / aurora today are **bootstrap applyables** (config + partial deps)—promote to `fidelity=full` only after full recipes exist.

---

## Phased plan

### Phase 0 — Docs & labels (now)

- Document this plan (this file).
- UI/CLI copy: Collection = apply store; HoF = gallery; 1:1 = full recipe only.

### Phase 1 — Recipe schema + installer skeleton

- Extend Collection rice files with `deploy`, `wallpapers`, `fonts`, `fidelity`.
- Extend install to deploy multiple trees + fetch assets.
- Extend validate to scan autostart scripts + require full recipe fields for `fidelity=full`.

### Phase 2 — First full rice (reference implementation)

Pick one (prefer **aurora** or **moon-rice**):

1. Inventory stack from README + autostart + gallery video.  
2. Fill complete recipe.  
3. Package missing bits or drop from apply.  
4. `validate` → YES.  
5. Manual visual check vs HoF thumbnail/video.  
6. Pin Collection; ship.

### Phase 3 — Second rice + tooling

- Repeat for the other bootstrap rice.  
- Expand nixpkgs bin map / font helpers.  
- Optional: `ncc hyprland rice inventory <id>` to help maintainers list execs/assets.

### Phase 4 — Scale HoF

- For each HoF entry: recipe or stay preview.  
- Blockers that stay preview forever without packaging work:
  - no hypr config in upstream  
  - dead clone URL  
  - binaries not in nixpkgs (e.g. custom daemons)  
  - whole apps (Flutter shell) without a Nix package  

### Phase 5 — Optional hardening

- VM / screenshot diff vs gallery  
- Home-manager integration for user-level themes  
- Flake rices only if module eval is proven dry-run  

---

## Maintainer workflow

1. Choose rice; study upstream + HoF entry.  
2. Write Collection recipe (`fidelity=full`).  
3. Attribution section in Collection README (author, repo, license note, HoF link).  
4. `ncc hyprland rice validate <id>` → must be YES.  
5. Apply on a test host; compare to gallery.  
6. Push Collection; bump `lib/collection-pin.nix` in NixOSControlCenter.  

---

## Legal (summary)

- Collection: MIT for **our** catalog/docs; **do not vendor** upstream trees.  
- Upstream often has **no LICENSE** → all rights remain with the author; we only link and clone at install.  
- Document that clearly per author in the Collection README.

---

## Related docs

- [architecture.md](./architecture.md) — catalogs, applyMethod, data flow  
- [usage.md](./usage.md) — user-facing commands  
- Collection repo: https://github.com/fr4iser90/NCC-Hyperland-Collection  
- Hall of Fame: https://hypr.land/hall_of_fame/
