{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, moduleName, ... }:
let
  # Generischen Pfad aus Dateisystem ableiten
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath;  # NO FALLBACKS!

  cfg = getModuleConfig moduleName;
  # Use the template file as default config
  defaultConfig = builtins.readFile ./template-config.nix;

  # Import utilities
  ccLib = import ./lib { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };

  # Import scripts from scripts/ directory
  mainScript = import ./scripts/main-script.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi getCurrentModuleMetadata moduleName;
  };
  aliases = import ./scripts/aliases.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };

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
  # ${configPath}.api = apiValue;
  core.management.cli-registry.api = apiValue;

  # Add NCC to system packages (always available)
  environment.systemPackages = [
    mainScript
  ];
}

