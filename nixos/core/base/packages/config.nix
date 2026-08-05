{ config, lib, pkgs, getModuleConfig, moduleName, ... }:
let
  cfg = getModuleConfig moduleName;
  systemManagerCfg = getModuleConfig "system-manager";

  # Import package module metadata for validation (feature sets: gaming, docker, …)
  packageMetadata = import ./lib/metadata.nix;

  # Individual package names (firefox, git, …) resolve via nixpkgs or optional metadata.package
  isResolvablePkg = pkg:
    let meta = packageMetadata.modules.${pkg} or {};
    in (meta ? package) || (builtins.hasAttr pkg pkgs);
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
  # Validate systemPackages as nixpkgs attr names (not packageModules)
  (let systemPkgs = cfg.systemPackages or []; in
   if systemPkgs != [] then [
     {
       assertion = lib.all isResolvablePkg systemPkgs;
       message = "Unknown system package(s): ${lib.concatStringsSep ", " (lib.filter (pkg: !(isResolvablePkg pkg)) systemPkgs)}";
     }
   ] else []) ++
  # Validate userPackages the same way
  lib.concatLists (lib.mapAttrsToList (user: packages: [
    {
      assertion = lib.all isResolvablePkg packages;
      message = "Unknown user package(s) for ${user}: ${lib.concatStringsSep ", " (lib.filter (pkg: !(isResolvablePkg pkg)) packages)}";
    }
  ]) (cfg.userPackages or {}));
}
