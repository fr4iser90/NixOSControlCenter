{
  description = "NixOS Configuration with Home Manager";

  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Home-Manager Inputs für verschiedene Versionen
    home-manager-stable.url = "github:nix-community/home-manager/release-25.11";
    home-manager-unstable.url = "github:nix-community/home-manager";

    # For TUI engine Go building
    gomod2nix.url = "github:nix-community/gomod2nix";

    configs.url = "path:./configs";
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

    # Load and merge all configs using centralized loader
    # Only loads modular configs from configs directory
    dummyCopy = builtins.readDir ./configs;
    systemConfig = configLoader.loadSystemConfig ./. configs;

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

    # Set stateVersion once for both system and home-manager
    # NOTE: Version wird oben in inputs definiert - hier nur stateVersion setzen
    stateVersion = if systemConfig.core.management.system-manager.system.channel == "stable"
      then "25.11"
      else "25.11"; # Use latest stable for unstable as well, or set to a default

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = systemConfig.core.management.system-manager.allowUnfree or false;
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

  in {
    nixosConfigurations = {
      "${systemConfig.core.base.network.hostName}" = nixpkgs.lib.nixosSystem {
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
            # System Version
            system.stateVersion = stateVersion;

            nix.settings.experimental-features = [ "nix-command" "flakes" ];

            # Unfree Konfiguration
            nixpkgs.config = {
              allowUnfree = systemConfig.core.management.system-manager.allowUnfree or false;
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
              }) (systemConfig.core.base.user or {});
            };
          }
        ];
      };
    };
  };
}
