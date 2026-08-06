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
    system = "x86_64-linux";

    # Import config loader from system-manager
    # This centralizes config loading logic - can be used by both flake.nix and system-manager module
    # Note: lib is not available yet at this point, so config-loader must work without it
    configLoader = import ./core/management/system-manager/lib/config-loader.nix {};

    # Dual layout (v2):
    #   monolith → ./systemConfig.nix (nested attrset, default for new installs)
    #   split    → ./systemConfig/**/config.nix
    systemConfig = configLoader.loadSystemConfig {
      flakeRoot = ./.;
      configsPath = configs;
      monolithPath = if builtins.pathExists ./systemConfig.nix then ./systemConfig.nix else null;
    };

    # Import module discovery for automatic config paths (after systemConfig is loaded)
    discoveryLib = import ./core/management/module-manager/lib/discovery.nix;
    moduleConfigLib = import ./core/management/module-manager/lib/module-config.nix;

    # Wähle das richtige nixpkgs und home-manager basierend auf der Konfiguration
    nixpkgs = if systemConfig.core.management.system-manager.system.channel == "stable"
              then nixpkgs-stable
              else nixpkgs-unstable;

    home-manager = if systemConfig.core.management.system-manager.system.channel == "stable"
                   then home-manager-stable
                   else home-manager-unstable;

    # stateVersion for systems built from this flake (new installs / repo template).
    # Must match the nixos-YY.MM pin above. Do not confuse with live-host upgrades:
    # bumping channels on an existing machine should usually leave its stateVersion alone.
    nixosRelease = "26.05";
    stateVersion = nixosRelease;

    pkgs = import nixpkgs {
      inherit system;
      # Match system-manager template-config default (true). Raw systemConfig
      # is not template-merged here — `or false` wrongly blocked unfree pkgs
      # (zoom, steam, …) when the attr was simply missing from live config.
      config.allowUnfree = systemConfig.core.management.system-manager.allowUnfree or true;
    };
    lib = pkgs.lib;

    # Now that we have lib, we can create the module config and discovery
    discovery = discoveryLib { inherit lib; };
    moduleConfig = moduleConfigLib { inherit lib systemConfig; };
    getModuleConfig = moduleConfig.getModuleConfig;
    getModuleMetadata = moduleConfig.getModuleMetadata;
    getCurrentModuleMetadata = moduleConfig.getCurrentModuleMetadata;
    getModuleApi = moduleConfig.getModuleApi;


    # Base modules required for all systems
    systemModules = [
      ./hardware-configuration.nix
      ./core
      # Safe import: only import modules/ if it exists
      (if builtins.pathExists ./modules/default.nix then ./modules else {})
      ./custom
    ];

  in let

    # NixOS system definition — factored out so we can reference it from multiple attrs
    mkSystem = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit systemConfig discovery moduleConfig getModuleConfig getModuleMetadata getCurrentModuleMetadata getModuleApi;
        # For TUI engine Go building
        buildGoApplication = gomod2nix.legacyPackages.${system}.buildGoApplication;
        gomod2nix = gomod2nix.legacyPackages.${system};
      };

      modules = [
        ./core/management/module-manager
      ] ++ systemModules ++ [
        {
          system.stateVersion = stateVersion;
          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          # Unfree — same default as template-config / pkgs import above
          nixpkgs.config = {
            allowUnfree = systemConfig.core.management.system-manager.allowUnfree or true;
          };
        }

        # Home Manager integration
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

  in {
    nixosConfigurations = {
      "${systemConfig.core.base.network.hostName}" = mkSystem;
    };
  };
}
