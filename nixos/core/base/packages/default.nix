{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  # Discovery: Modulname aus Dateisystem ableiten
  moduleName = baseNameOf ./. ;  # ← packages aus core/base/packages/
  cfg = getModuleConfig moduleName;
  systemManagerCfg = getModuleConfig "system-manager";  # Anderes Modul, bleibt hardcoded
  cfgRaw = lib.attrByPath ["core" "base" "packages"] {} systemConfig;
  systemManagerCfgRaw = lib.attrByPath ["core" "management" "system-manager"] {} systemConfig;

  # Import package module metadata for validation
  packageMetadata = import ./lib/metadata.nix;

  # Load base packages
  basePackages = {
    desktop = import ./components/base/desktop.nix;
    server = import ./components/base/server.nix;
  };


  # Load package modules (V1 format)
  allModules = cfgRaw.packageModules or [];

  # Determine actual Docker mode - enabled if "docker" or "docker-rootless" in packageModules
  dockerMode = let
    hasDocker = builtins.elem "docker" allModules;
    hasDockerRootless = builtins.elem "docker-rootless" allModules;
  in
    if hasDocker then "root"
    else if hasDockerRootless then "rootless"
    else null;

  # Smart Docker handling
  dockerModules = if dockerMode == "root" then [ ./components/sets/docker.nix ]
               else if dockerMode == "rootless" then [ ./components/sets/docker-rootless.nix ]
               else [];

  # Load feature modules
  moduleModules = map (mod: ./components/sets/${mod}.nix) allModules;

in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Package management system";
    category = "base";
    subcategory = "packages";
    version = "1.0.0";
  };

  imports = [
    ./options.nix
    (import ./config.nix { inherit config lib pkgs getModuleConfig moduleName; })
    ./commands.nix
    ./components/base/desktop.nix
    ./components/base/server.nix
  ] ++ moduleModules ++ dockerModules;

  # System packages from systemPackages option
  environment.systemPackages = lib.mkIf ((cfg.systemPackages or []) != []) (
    map (pkgName:
      let
        meta = packageMetadata.modules.${pkgName} or {};
      in
        if meta ? package then meta.package
        else if builtins.hasAttr pkgName pkgs then pkgs.${pkgName}
        else throw "Package '${pkgName}' not found in package metadata or nixpkgs"
    ) cfg.systemPackages
  );

  # Home-manager integration for userPackages (only if home-manager is available)
  home-manager = lib.mkIf (cfg.userPackages or {} != {}) {
    users = lib.mapAttrs (userName: packages:
      { config, ... }: {
        home.packages = map (pkgName:
          let
            meta = packageMetadata.modules.${pkgName} or {};
          in
            if meta ? package then meta.package
            else if builtins.hasAttr pkgName pkgs then pkgs.${pkgName}
            else throw "Package '${pkgName}' not found in package metadata or nixpkgs"
        ) packages;
      }
    ) cfg.userPackages;
  };

}