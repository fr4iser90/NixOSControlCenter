# This module provides a CLI management system for NixOS.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.cli-management;
  
  cliConfig = {
    prefix = cfg.prefix;
    categories = cfg.categories;
  };
  
  cliTools = import ./lib/tools.nix { 
    inherit lib pkgs cliConfig;
  };
in {
  # Exportiere cliTools für andere Module
  options.cli-management = {
    enable = mkEnableOption "CLI Management";

    prefix = mkOption {
      type = types.str;
      default = "ncc";
      description = "Prefix for all CLI commands";
    };

    categories = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Command categories provided by modules";
    };

    tools = mkOption {
      type = types.attrs;
      default = cliTools;
      description = "CLI tools for other modules";
      internal = true;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      (cliTools.mkCommandWrapper)
    ];
  };
}