# Build-time JSON export of the packages catalog (sets / recipes / user-presets).
{ pkgs }:

let
  data = import ./catalog.nix {
    metadata = import ./metadata.nix;
    setsDir = ../components/sets;
    recipesDir = ../components/recipes;
    userPresetsDir = ../components/user-presets;
  };
  export = {
    sets = data.sets;
    recipes = data.recipes;
    userPresets = data.userPresets;
    # Back-compat for GUI iterating .presets
    presets = data.presets;
    setNames = data.setNames;
    recipeNames = data.recipeNames;
    userPresetNames = data.userPresetNames;
    presetNames = data.presetNames;
  };
in
pkgs.writeText "ncc-packages-catalog.json" (builtins.toJSON export)
