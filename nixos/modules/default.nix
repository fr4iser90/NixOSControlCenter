{ lib, ... }:
let
  # Discovers ALL module directories automatically
  discoveredModules = lib.filterAttrs (name: type:
    type == "directory" &&
    builtins.pathExists (./. + "/${name}/default.nix")
  ) (builtins.readDir ./.);

in {
  imports = lib.mapAttrsToList (name: _type:
    ./. + "/${name}"  # AUTO IMPORT!
  ) discoveredModules;
}
