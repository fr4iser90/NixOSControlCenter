{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, corePathsLib, ... }:

let
  cfg = getModuleConfig "system-update";

  # Import the UI from the cli-formatter submodule (generic)
  ui = getModuleApi "system-manager";
  cliRegistry = getModuleApi "cli-registry";

  # Import the actual system update script from handlers
  systemUpdateHandler = import ./handlers/system-update.nix { 
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi corePathsLib; 
  };
  systemUpdateMainScript = systemUpdateHandler.systemUpdateMainScript;

in
  lib.mkIf (cfg.enable or true)
    (cliRegistry.registerCommandsFor "system-update" [
      {
        name = "system-update";
        script = "${systemUpdateMainScript}/bin/ncc-system-update-main";
        category = "System Management";
        description = "Update NixOS configuration from repository";
        help = "system-update [--auto-build] [--source=remote|local] [--branch=name] - Update NixOS configuration";
      }
    ])
