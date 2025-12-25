{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleMetadata, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;        # "lock-manager" - automatisch!

  # Module metadata (REQUIRED - define directly here)
  metadata = {
    role = "optional";
    name = moduleName;
    description = "System state discovery, encryption, and backup management";
    category = "system";
    subcategory = "lock";
    stability = "stable";
    version = "1.0.0";
  };

  cfg = getModuleConfig moduleName;
  
in {
  # REQUIRED: Export metadata for discovery system
  _module.metadata = metadata;

  imports = [
    ./options.nix  # Always import options first
  ] ++ (if (cfg.enable or false) then [
    ./commands.nix  # Command registration
    ./config.nix    # Implementation logic
  ] else []);

  config = lib.mkMerge [
    # Generisch: enable-Flag aus Discovery-Pfad setzen
    (let
      moduleMeta = getModuleMetadata moduleName;
      enablePath = lib.splitString "." moduleMeta.enablePath;
    in
      lib.setAttrByPath enablePath (lib.mkDefault (cfg.enable or false))
    )
  ];
}

