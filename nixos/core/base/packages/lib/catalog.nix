# Packages catalog — Nix SSOT for sets/presets.
# Import from a tree that still has metadata.nix + components/ (not a lone store copy).
# For GUIs prefer: import ./mk-catalog-json.nix { inherit pkgs; }
{ metadata, setsDir, presetsDir }:

let
  setFiles =
    if builtins.pathExists setsDir
    then builtins.attrNames (builtins.readDir setsDir)
    else [];
  setNames = map (f: builtins.substring 0 (builtins.stringLength f - 4) f)
    (builtins.filter (f: builtins.match ".*\\.nix" f != null) setFiles);

  presetFiles =
    if builtins.pathExists presetsDir
    then builtins.attrNames (builtins.readDir presetsDir)
    else [];
  presetNames = map (f: builtins.substring 0 (builtins.stringLength f - 4) f)
    (builtins.filter (f: builtins.match ".*\\.nix" f != null) presetFiles);

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
    };

  presetEntry = name:
    let
      p = import (presetsDir + "/${name}.nix");
    in {
      inherit name;
      kind = "preset";
      description = p.description or "";
      systemTypes = p.systemTypes or [];
      modules = p.modules or [];
    };
in
{
  inherit metadata;
  sets = map setEntry setNames;
  presets = map presetEntry presetNames;
  inherit setNames presetNames;
}
