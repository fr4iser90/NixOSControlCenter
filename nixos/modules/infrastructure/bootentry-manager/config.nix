{ config, lib, pkgs, systemConfig, getModuleMetadata, moduleName, configHelpers, ... }:

let
  # Modulname kommt aus default.nix (single source of truth)
  moduleMeta = getModuleMetadata moduleName;
  cfg = lib.attrByPath (lib.splitString "." moduleMeta.configPath) {} systemConfig;
  # Use the template file as default config
  defaultConfig = builtins.readFile ./template-config.nix;
in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or false)
      (configHelpers.createModuleConfig {
        moduleName = moduleMeta.name;
        defaultConfig = defaultConfig;
      })
    )
    # Boot entry module implementation is handled in default.nix
  ]
