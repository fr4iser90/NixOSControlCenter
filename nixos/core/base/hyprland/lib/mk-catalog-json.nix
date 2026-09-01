# Build-time JSON export of the hyprland rice catalog (CLI / GUI store).
{ pkgs }:

let
  lib = pkgs.lib;
  catalog = import ./rice-catalog.nix;

  isApplyable = rice:
    let
      method = rice.applyMethod or "reference";
    in
      (method == "dotfiles" && (rice.dotfiles.cloneUrl or "") != "")
      || (method == "flake" && rice ? flake && (rice.flake.url or "") != "")
      || (method == "wallpaper" && rice.thumbnailHash != null);

  applyLabel = rice:
    let
      method = rice.applyMethod or "reference";
    in
      if method == "flake" then "Nix flake + dotfiles"
      else if method == "dotfiles" then "Dotfiles collection"
      else if method == "wallpaper" then "Wallpaper only"
      else "Reference only";

  enrich = rice:
    let
      preview =
        if rice.thumbnailHash != null then
          pkgs.fetchurl {
            url = rice.thumbnailUrl;
            hash = rice.thumbnailHash;
          }
        else null;
      applyable = isApplyable rice;
      previewPath =
        if preview != null then
          builtins.unsafeDiscardStringContext (toString preview)
        else null;
    in
      rice
      // {
        inherit applyable;
        applyLabel = applyLabel rice;
        previewStorePath = previewPath;
      };

  entries = lib.mapAttrsToList (_: v: v) catalog;
  enriched = map enrich entries;
  applyableRices = lib.filter (r: r.applyable) enriched;
  contests = lib.unique (map (r: r.contest) applyableRices);
  categories = map (n:
    let
      sample = lib.head (lib.filter (r: r.contest == n) applyableRices);
    in {
      id = "contest-${toString n}";
      title = "Contest #${toString n}: ${sample.theme}";
      contest = n;
    }
  ) (lib.sort (a: b: a < b) contests);
  export = {
    inherit categories;
    rices = enriched;
    storeRices = applyableRices;
    riceIds = builtins.attrNames catalog;
    applyableIds = map (r: r.id) applyableRices;
    riceNames = map (r: r.name) enriched;
  };
in
pkgs.writeText "ncc-hyprland-catalog.json" (builtins.toJSON export)
