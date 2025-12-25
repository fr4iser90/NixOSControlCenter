{ config, lib, pkgs, getModuleConfig, moduleName, ... }:
let
  cfg = getModuleConfig moduleName;
  systemManagerCfg = getModuleConfig "system-manager";

  # Import package module metadata for validation
  packageMetadata = import ./lib/metadata.nix;
in {
  # Packages module - no direct NixOS configuration needed
  # All configuration is handled through packageModules in default.nix

  # Validate packageModules against metadata
  assertions = [
    {
      assertion = lib.all (mod: packageMetadata.modules.${mod} or null != null) cfg.packageModules;
      message = "Unknown package module(s): ${lib.concatStringsSep ", " (lib.filter (mod: !(packageMetadata.modules.${mod} or null != null)) cfg.packageModules)}";
    }
    {
      assertion = lib.all (mod:
        let meta = packageMetadata.modules.${mod};
        in meta.systemTypes == [] || builtins.elem (systemManagerCfg.systemType or "desktop") meta.systemTypes
      ) cfg.packageModules;
      message = "Package module(s) not compatible with system type: ${lib.concatStringsSep ", " (lib.filter (mod:
        let meta = packageMetadata.modules.${mod};
        in meta.systemTypes != [] && !(builtins.elem (systemManagerCfg.systemType or "desktop") meta.systemTypes)
      ) cfg.packageModules)}";
    }
  ];
}