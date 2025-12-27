{ config, lib, pkgs, buildGoApplication, gomod2nix, ... }:

let
  # API wie cli-registry - kein cfg Build-Time dependency
  apiValue = import ./api.nix { inherit lib config; };
in {
  # Import the TUI script module like SSH manager
  imports = [ ./scripts/module-manager-tui.nix ];

  # Config setzen (hardcoded path wie cli-registry)
  config.core.management.tui-engine = {
    api = apiValue;
    buildGoApplication = buildGoApplication;
    gomod2nix = gomod2nix;
    writeScriptBin = pkgs.writeScriptBin;
    installShellFiles = pkgs.installShellFiles;
  };
}
