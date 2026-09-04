{
  description = "NixOS Configuration with Home Manager";

  inputs = {
    # SSOT stable release: keep nixpkgs-stable, home-manager-stable, and stateVersion in sync.
    # Repo bump: shell/scripts/checks/system/check-nixos-version.sh
    # Live hosts: ncc system update-channels --bump-to YY.MM (inputs only; stateVersion unchanged)
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home-Manager Inputs für verschiedene Versionen
    home-manager-stable.url = "github:nix-community/home-manager/release-26.05";
    home-manager-unstable.url = "github:nix-community/home-manager";

    # For TUI engine Go building
    gomod2nix.url = "github:nix-community/gomod2nix";

    configs.url = "path:./systemConfig";
    configs.flake = false;

    # ncc-hyprland-rice-inputs-begin
    # (no active hyprland rice flake)
    # ncc-hyprland-rice-inputs-end
  };

  outputs = { self
    , nixpkgs-stable
    , nixpkgs-unstable
    , home-manager-stable
    , home-manager-unstable
    , gomod2nix
    , configs
    , ...
  }: let
    configLoader = import ./core/management/system-manager/lib/config-loader.nix {};

    systemConfig = configLoader.loadSystemConfig {
      flakeRoot = ./.;
      configsPath = configs;
      monolithPath = if builtins.pathExists ./systemConfig.nix then ./systemConfig.nix else null;
      layout = "auto";
    };

    hostname = systemConfig.core.base.network.hostName or "nixos";

    # Match platform string in Nix source text (mkDefault + spacing; flatten newlines)
    matchPlatform = text:
      let
        flat = builtins.replaceStrings [ "\n" "\t" ] [ " " " " ] text;
        mDotted = builtins.match ".*system\\.platform[[:space:]]*=[[:space:]]*(lib\\.mkDefault[[:space:]]+)?\"([^\"]+)\".*" flat;
        mHost = builtins.match ".*nixpkgs\\.hostPlatform[[:space:]]*=[[:space:]]*(lib\\.mkDefault[[:space:]]+)?\"([^\"]+)\".*" flat;
        mSys = builtins.match ".*nixpkgs\\.system[[:space:]]*=[[:space:]]*(lib\\.mkDefault[[:space:]]+)?\"([^\"]+)\".*" flat;
      in
        if mDotted != null then builtins.elemAt mDotted 1
        else if mHost != null then builtins.elemAt mHost 1
        else if mSys != null then builtins.elemAt mSys 1
        else null;

    # Host platform SSOT — pure only (no --impure / no builtins.currentSystem):
    #   1) systemConfig attr  2) monolith/leaf text  3) hardware-configuration.nix
    # Persisted by install / migrate / preflight / ncc system-update (ensure before build).
    resolvedSystem =
      let
        sm = systemConfig.core.management.system-manager or {};
        fromAttr = (sm.system or {}).platform or null;
        fromMono =
          if builtins.pathExists ./systemConfig.nix
          then matchPlatform (builtins.readFile ./systemConfig.nix)
          else null;
        fromLeaf =
          if builtins.pathExists ./systemConfig/core/management/system-manager/config.nix
          then matchPlatform (builtins.readFile ./systemConfig/core/management/system-manager/config.nix)
          else null;
        fromHw =
          if builtins.pathExists ./hardware-configuration.nix
          then matchPlatform (builtins.readFile ./hardware-configuration.nix)
          else null;
      in
        if fromAttr != null && fromAttr != "" then fromAttr
        else if fromMono != null && fromMono != "" then fromMono
        else if fromLeaf != null && fromLeaf != "" then fromLeaf
        else if fromHw != null && fromHw != "" then fromHw
        else null;

    nixpkgs = if (systemConfig.core.management.system-manager.system.channel or "stable") == "stable"
              then nixpkgs-stable
              else nixpkgs-unstable;

    home-manager = if (systemConfig.core.management.system-manager.system.channel or "stable") == "stable"
                   then home-manager-stable
                   else home-manager-unstable;

    nixosRelease = "26.05";
    stateVersion = nixosRelease;

    mkSystem = system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = systemConfig.core.management.system-manager.allowUnfree or true;
        };
        lib = pkgs.lib;
        discoveryLib = import ./core/management/module-manager/lib/discovery.nix;
        moduleConfigLib = import ./core/management/module-manager/lib/module-config.nix;
        discovery = discoveryLib { inherit lib; };
        moduleConfig = moduleConfigLib { inherit lib systemConfig; };
        getModuleConfig = moduleConfig.getModuleConfig;
        getModuleMetadata = moduleConfig.getModuleMetadata;
        getCurrentModuleMetadata = moduleConfig.getCurrentModuleMetadata;
        getModuleApi = moduleConfig.getModuleApi;
        systemModules = [
          ./hardware-configuration.nix
          ./core
          (if builtins.pathExists ./modules/default.nix then ./modules else {})
          (if builtins.pathExists ./custom then ./custom else {})
        ];
      in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit systemConfig discovery moduleConfig getModuleConfig getModuleMetadata getCurrentModuleMetadata getModuleApi;
            buildGoApplication = gomod2nix.legacyPackages.${system}.buildGoApplication;
            gomod2nix = gomod2nix.legacyPackages.${system};
          };
          modules = [
            ./core/management/module-manager
          # ncc-hyprland-rice-modules-begin
          ] ++ systemModules ++ lib.optionals false [ null ]
          # ncc-hyprland-rice-modules-end
          ++ [
            {
              system.stateVersion = stateVersion;
              nix.settings.experimental-features = [ "nix-command" "flakes" ];
              nixpkgs.config = {
                allowUnfree = systemConfig.core.management.system-manager.allowUnfree or true;
              };
            }
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit systemConfig discovery moduleConfig getModuleConfig getModuleMetadata getCurrentModuleMetadata;
                };
                users = lib.mapAttrs (username: userConfig:
                  { config, ... }: {
                    imports = [
                      (import ./core/base/user/home-manager/roles/${userConfig.role}.nix {
                        inherit pkgs lib config systemConfig getModuleConfig;
                        user = username;
                      })
                    ];
                    home = {
                      username = username;
                      homeDirectory = "/home/${username}";
                      stateVersion = stateVersion;
                    };
                  }) (lib.filterAttrs (_: v: builtins.isAttrs v)
                     (systemConfig.core.base.user or {}));
              };
            }
          ];
        };

    # Always expose both arches for rescue; primary hostname uses resolvedSystem.
    # If still null (rare: no platform in config AND no hardware-configuration in flake
    # source), primary uses x86_64 only as last resort WITH trace — Orin hosts must have
    # hostPlatform in hardware-configuration or platform in systemConfig (install/update).
    primarySystem =
      if resolvedSystem != null then resolvedSystem
      else
        builtins.trace
          "ncc: system.platform unset and hardware-configuration.nix not in flake source — temporary x86_64-linux; ncc system-update will persist platform from uname"
          "x86_64-linux";

  in {
    nixosConfigurations = {
      "${hostname}" = mkSystem primarySystem;
      "${hostname}-x86_64-linux" = mkSystem "x86_64-linux";
      "${hostname}-aarch64-linux" = mkSystem "aarch64-linux";
    };
  };
}
