{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  systemManagerCfg = getModuleConfig "system-manager";

  # Import package module metadata for validation
  packageMetadata = import ./lib/metadata.nix;

  # Load base packages
  basePackages = {
    desktop = import ./components/base/desktop.nix;
    server = import ./components/base/server.nix;
  };


  # Load package modules (V1 format)
  allModules = cfg.packageModules or [];

  # Smart Docker: rootless by default; root for Swarm / AI-Workspace; docker.root override
  dockerMode = import ./lib/docker-mode.nix {
    inherit systemConfig;
    packageModules = allModules;
    dockerRoot = (cfg.docker.root or null);
    dockerEnable = (cfg.docker.enable or false);
  };

  dockerModules =
    if dockerMode == "root" then [ ./components/sets/docker.nix ]
    else if dockerMode == "rootless" then [ ./components/sets/docker-rootless.nix ]
    else [];

  # Do not also import docker*.nix via the generic map (handled by dockerModules)
  featureModules = builtins.filter
    (m: m != "docker" && m != "docker-rootless")
    allModules;
  moduleModules = map (mod: ./components/sets/${mod}.nix) featureModules;

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