# This module provides a CLI management system for NixOS.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.virtualisation.management;
  
  # Hier erstellen wir die cliConfig
  cliConfig = {
    prefix = "ncc";
    categories = {
      vm = "Virtual Machine Management";
      # ... andere Kategorien ...
    };
  };
  
  # Jetzt übergeben wir cliConfig statt nichts
  cliTools = import ../cli-management/lib/tools.nix { 
    inherit lib pkgs cliConfig;  # <-- Hier übergeben wir cliConfig
  };
in {


  options.cli-management = {
    enable = mkEnableOption "CLI Management";

    prefix = mkOption {
      type = types.str;
      default = "ncc";
      description = "Prefix for all CLI commands";
    };

    categories = mkOption {
      type = types.attrsOf types.str;
      default = {
        sys = "System Management";
        net = "Network Management";
        vm = "Virtual Machine Management";
        dev = "Development Tools";
        pkg = "Package Management";
        user = "User Management";
        hw = "Hardware Management";
      };
      description = "Available command categories with descriptions";
    };

    enabledCategories = mkOption {
      type = types.listOf (types.enum (attrNames cfg.categories));
      default = [];
      description = "Enabled command categories";
    };
  };

  config = mkIf cfg.enable {
    # Stelle sicher, dass die lib-Tools überall verfügbar sind
    environment.systemPackages = [
      (import ./lib/tools.nix { inherit lib pkgs; }).mkCommandWrapper
    ];
  };
}