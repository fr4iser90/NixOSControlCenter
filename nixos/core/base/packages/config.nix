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

  # homelab is server-class for package-set compatibility (docker, database, …)
  rawSystemType = systemManagerCfg.systemType or "desktop";
  compatSystemType = if rawSystemType == "homelab" then "server" else rawSystemType;

  packageModules = cfg.packageModules or [];
  dockerEnable = cfg.docker.enable or false;
  hasDocker =
    lib.elem "docker" packageModules
    || lib.elem "docker-rootless" packageModules
    || dockerEnable;
in {
  # Packages module - no direct NixOS configuration needed
  # All configuration is handled through packageModules in default.nix

  # Homelab: expect docker (seed via prebuild-check-packages when packages empty).
  # Not a hard assertion — hosts may opt out after an explicit non-empty packages config.
  warnings = lib.optional (rawSystemType == "homelab" && !hasDocker) ''
    systemType=homelab but Docker is not enabled.
    Add packageModules = [ "docker" ] or docker.enable = true,
    or run: ncc system build switch (preflight can seed when packages are empty).
  '';

  # Validate packageModules against metadata
  assertions = [
    {
      assertion = lib.all (mod: packageMetadata.modules.${mod} or null != null) cfg.packageModules;
      message = "Unknown package module(s): ${lib.concatStringsSep ", " (lib.filter (mod: !(packageMetadata.modules.${mod} or null != null)) cfg.packageModules)}";
    }
    {
      assertion = lib.all (mod:
        let meta = packageMetadata.modules.${mod};
        in meta.systemTypes == [] || builtins.elem compatSystemType meta.systemTypes
      ) cfg.packageModules;
      message = "Package module(s) not compatible with system type (${rawSystemType}): ${lib.concatStringsSep ", " (lib.filter (mod:
        let meta = packageMetadata.modules.${mod};
        in meta.systemTypes != [] && !(builtins.elem compatSystemType meta.systemTypes)
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
   ] else []);
}
