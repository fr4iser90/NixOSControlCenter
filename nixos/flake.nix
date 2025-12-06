{
  description = "NixOS Configuration with Home Manager";

  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Home-Manager Inputs für verschiedene Versionen
    home-manager-stable.url = "github:nix-community/home-manager/release-25.11";
    home-manager-unstable.url = "github:nix-community/home-manager";
  };

  outputs = { self
    , nixpkgs-stable
    , nixpkgs-unstable
    , home-manager-stable
    , home-manager-unstable
    , ... 
  }: let
    system = "x86_64-linux";
    
    # Helper function to load config if it exists
    loadConfig = configName:
      if builtins.pathExists ./configs/${configName}-config.nix
      then import ./configs/${configName}-config.nix
      else {};
    
    # List of optional config files (in merge order)
    optionalConfigs = [
      "desktop"
      "localization"
      "hardware"
      "features"
      "packages"
      "network"
      "security"
      "performance"
      "storage"
      "monitoring"
      "backup"
      "logging"
      "update"
      "services"
      "virtualization"
      "hosting"
      "environment"
      "identity"
      "certificates"
      "compliance"
      "ha"
      "disaster-recovery"
      "secrets"
      "multi-tenant"
      "overrides"
    ];
    
    # 1. Load minimal system-config (MUST exist)
    # If old structure: contains all values, will be overridden by optional configs
    baseConfig = import ./system-config.nix;
    
    # 2. Load and merge all optional configs
    # Order is important: later configs override earlier ones
    systemConfig = baseConfig // builtins.foldl' (acc: configName: acc // loadConfig configName) {} optionalConfigs;
    
    # Wähle das richtige nixpkgs und home-manager basierend auf der Konfiguration
    nixpkgs = if systemConfig.system.channel == "stable"
              then nixpkgs-stable
              else nixpkgs-unstable;
              
    home-manager = if systemConfig.system.channel == "stable"
                   then home-manager-stable
                   else home-manager-unstable;

    # Set stateVersion once for both system and home-manager
    # NOTE: Version wird oben in inputs definiert - hier nur stateVersion setzen
    stateVersion = if systemConfig.system.channel == "stable"
      then "25.11"
      else "25.11"; # Use latest stable for unstable as well, or set to a default
    
    pkgs = import nixpkgs { 
      inherit system;
      config.allowUnfree = systemConfig.allowUnfree or false;
    };
    lib = pkgs.lib;

    # Base modules required for all systems
    systemModules = [
      ./hardware-configuration.nix
      ./core
      ./packages
      ./features
      ./custom
    ];

  in {
    nixosConfigurations = {
      "${systemConfig.hostName}" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit systemConfig; }; 

        modules = systemModules ++ [      
          {
            # System Version
            system.stateVersion = stateVersion;

            nix.settings.experimental-features = [ "nix-command" "flakes" ];

            # Unfree Konfiguration
            nixpkgs.config = {
              allowUnfree = systemConfig.allowUnfree or false;
            };
          }     
          
          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit systemConfig; };
              users = lib.mapAttrs (username: userConfig: 
                { config, ... }: {
                  imports = [ 
                    (import ./core/user/home-manager/roles/${userConfig.role}.nix {
                      inherit pkgs lib config systemConfig;
                      user = username;
                    })
                  ];
                    home = {
                    username = username;
                    homeDirectory = "/home/${username}";
                    stateVersion = stateVersion;
                  };
              }) systemConfig.users;
            };
          }
        ];
      };
    };
  };
}
