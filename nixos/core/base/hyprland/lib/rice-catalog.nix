# Merged rice catalog: HoF gallery ∪ NCC-Hyperland-Collection applyables.
# Collection wins on id collision (applyable replaces HoF reference).
#
# Optional pkgs: enables GitHub fetch when sibling checkout is missing.
{ pkgs ? null }:
let
  hof = import ./rice-catalog-hof.nix;

  siblingCatalog = ../../../../../../NCC-Hyperland-Collection/nix/catalog.nix;

  collectionRices =
    if builtins.pathExists siblingCatalog then
      (import siblingCatalog { }).rices
    else if pkgs != null then
      let
        src = import ./load-collection-src.nix { inherit pkgs; };
      in (import "${src}/nix/catalog.nix" { }).rices
    else
      { };
in
  hof // collectionRices
