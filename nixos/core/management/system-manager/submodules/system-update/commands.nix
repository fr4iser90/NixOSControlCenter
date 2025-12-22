{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  cfg = getModuleConfig "system-update";

  # Import the UI from the cli-formatter submodule (generic)
  ui = getModuleApi "system-manager";

  # System update main script (extracted from the old handler)
  systemUpdateMainScript = pkgs.writeScriptBin "ncc-system-update-main" ''
    #!/bin/bash
    # System update script - moved to submodule
    echo "System update functionality"
    # TODO: Extract full script from handlers/system-update.nix
  '';

in
  lib.mkIf (cfg.enable or true) {
    # Register the system-update command
    core.management.system-manager.submodules.cli-registry.commands = lib.mkAfter [
      {
        name = "system-update";
        script = "${systemUpdateMainScript}/bin/ncc-system-update-main";
        category = "System Management";
        description = "Update NixOS configuration from repository";
        help = "system-update [--auto-build] [--source=remote|local] [--branch=name] - Update NixOS configuration";
      }
    ];
  }
