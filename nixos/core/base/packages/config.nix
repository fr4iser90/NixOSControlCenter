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
  ] ++
  # Validate systemPackages (only if defined)
  (let systemPkgs = cfg.systemPackages or []; in
   if systemPkgs != [] then [
     {
       assertion = lib.all (pkg: packageMetadata.modules.${pkg} or null != null) systemPkgs;
       message = "Unknown system package(s): ${lib.concatStringsSep ", " (lib.filter (pkg: !(packageMetadata.modules.${pkg} or null != null)) systemPkgs)}";
     }
   ] else []) ++
  # Validate userPackages (only if defined)
  lib.concatLists (lib.mapAttrsToList (user: packages: [
    {
      assertion = lib.all (pkg: packageMetadata.modules.${pkg} or null != null) packages;
      message = "Unknown user package(s) for ${user}: ${lib.concatStringsSep ", " (lib.filter (pkg: !(packageMetadata.modules.${pkg} or null != null)) packages)}";
    }
  ]) (cfg.userPackages or {}));
}