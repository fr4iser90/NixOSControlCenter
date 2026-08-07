{ config, lib, pkgs, getCurrentModuleMetadata, ... }:

let
  moduleName = baseNameOf ./.;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Fleet host targets (reuse SSH client credentials)";
    category = "management";
    subcategory = "hosts";
    stability = "stable";
    version = "1.0.0";
  };

  imports = [
    ./options.nix
    ./commands.nix
  ];
}
