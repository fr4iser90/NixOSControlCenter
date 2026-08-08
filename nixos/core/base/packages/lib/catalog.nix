# Packages catalog — Nix SSOT for sets / recipes / user-presets.
# Prefer: import ./mk-catalog-json.nix { inherit pkgs; }
{ metadata, setsDir, recipesDir, userPresetsDir }:

let
  nixNames = dir:
    if builtins.pathExists dir
    then map (f: builtins.substring 0 (builtins.stringLength f - 4) f)
      (builtins.filter (f: builtins.match ".*\\.nix" f != null)
        (builtins.attrNames (builtins.readDir dir)))
    else [];

  setNames = nixNames setsDir;
  recipeNames = nixNames recipesDir;
  userPresetNames = nixNames userPresetsDir;

  setEntry = name:
    let
      meta = metadata.modules.${name} or { };
    in {
      inherit name;
      kind = "set";
      description = meta.description or "";
      group = meta.group or "";
      systemTypes = meta.systemTypes or [];
      dependencies = meta.dependencies or [];
      conflicts = meta.conflicts or [];
      requiresUnfree = meta.requiresUnfree or false;
      deprecatedAliasOf = meta.deprecatedAliasOf or null;
    };

  # System recipe: expands to packageModules (sets)
  recipeEntry = name:
    let p = import (recipesDir + "/${name}.nix");
    in {
      inherit name;
      kind = "recipe";
      scope = "system";
      description = p.description or "";
      systemTypes = p.systemTypes or [];
      modules = p.modules or [];
      packages = [];
    };

  # User preset: expands to users.<you>.userPackages
  userPresetEntry = name:
    let p = import (userPresetsDir + "/${name}.nix");
    in {
      inherit name;
      kind = "user-preset";
      scope = "user";
      description = p.description or "";
      systemTypes = p.systemTypes or [];
      modules = [];
      packages = p.packages or [];
    };

  # Combined list for GUIs that still iterate "presets"
  presets = (map recipeEntry recipeNames) ++ (map userPresetEntry userPresetNames);
  presetNames = recipeNames ++ userPresetNames;
in
{
  inherit metadata;
  sets = map setEntry setNames;
  recipes = map recipeEntry recipeNames;
  userPresets = map userPresetEntry userPresetNames;
  inherit setNames recipeNames userPresetNames presets presetNames;
}
