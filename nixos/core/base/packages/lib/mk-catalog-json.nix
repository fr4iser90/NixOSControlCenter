# Build-time JSON export of the packages catalog (sets/presets).
# Avoids pointing GUIs at a lone store copy of catalog.nix (relative imports break).
{ pkgs }:

let
  data = import ./catalog.nix {
    metadata = import ./metadata.nix;
    setsDir = ../components/sets;
    presetsDir = ../components/presets;
  };
  export = {
    sets = data.sets;
    presets = data.presets;
    setNames = data.setNames;
    presetNames = data.presetNames;
  };
in
pkgs.writeText "ncc-packages-catalog.json" (builtins.toJSON export)
