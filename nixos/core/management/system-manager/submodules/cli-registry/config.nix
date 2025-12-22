{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = getModuleConfig "cli-registry";
  configHelpers = import ../../../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./command-center-config.nix;

  # Import utilities
  ccLib = import ./lib { inherit lib; };

  # Import scripts from scripts/ directory
  mainScript = import ./scripts/main-script.nix { inherit config lib pkgs systemConfig getModuleConfig; };
  aliases = import ./scripts/aliases.nix { inherit config lib pkgs systemConfig getModuleConfig; };

  # API definition - always available
  # Commands werden von anderen Modulen hinzugefügt
  apiValue = {
    categories = [];  # Wird später berechnet
  };

in
{
  # CLI Registry is Core - always active like desktop
  # No enable option needed - NCC command always available

  # API is always available
  core.management.system-manager.submodules.cli-registry = {};
  core.management.system-manager.submodules.cli-registry.api = apiValue;

  # Add NCC to system packages (always available)
  environment.systemPackages = [
    mainScript
  ];
}

