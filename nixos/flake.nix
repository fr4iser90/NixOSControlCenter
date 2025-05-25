{
  description = "NixOS Configuration with Home Manager";

  inputs = {
    # Dynamische Inputs basierend auf Konfiguration
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Home-Manager Inputs für verschiedene Versionen
    home-manager-stable.url = "github:nix-community/home-manager/release-25.05";
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
    systemConfig = import ./system-config.nix;
    
    # Wähle das richtige nixpkgs und home-manager basierend auf der Konfiguration
    nixpkgs = if systemConfig.system.channel == "stable"
              then nixpkgs-stable
              else nixpkgs-unstable;
              
    home-manager = if systemConfig.system.channel == "stable"
                   then home-manager-stable
                   else home-manager-unstable;

    # Set stateVersion once for both system and home-manager
    stateVersion = if systemConfig.system.channel == "stable"
      then "25.05"
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
      ./desktop
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
