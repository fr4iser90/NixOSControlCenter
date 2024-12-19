{
  description = "NixOS Configuration with Home Manager (Unstable Channel)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = { self, nixpkgs, home-manager, ... }: let
    system = "x86_64-linux";
    systemConfig = import ./system-config.nix;
    
    pkgs = import nixpkgs { 
      inherit system;
      config.allowUnfree = systemConfig.allowUnfree or false;
    };
    lib = pkgs.lib;

    # Base modules required for all systems
    systemModules = [

      ./hardware-configuration.nix
      
      # Core system management
      ./modules/boot-management
      ./modules/nix-management
      ./modules/log-management
      
      # Hardware & Network
      ./modules/hardware-management
      ./modules/network-management
      ./modules/audio-management 
      
      # User management
      ./modules/user-management
      ./modules/profile-management
      ./modules/desktop-management
      ./modules/system-management
    ];


  in {
    nixosConfigurations = {
      "${systemConfig.hostName}" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit systemConfig; }; 

        modules = systemModules ++ [      
          # Unfree Konfiguration
          {
            nixpkgs.config = {
              allowUnfree = systemConfig.allowUnfree or false;
            };
          }     
            # Home Manager integration
            home-manager.nixosModules.home-manager
            {
              #system.stateVersion = "24.05"; # Deprecated
              #system.stateVersion = "24.11"; # stable Vicuna
              system.stateVersion = "25.05"; #  unstable Warbler
              
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit systemConfig; };
                users = lib.mapAttrs (username: userConfig: 
                    { config, ... }: {
                      imports = [ 
                        (import ./modules/user-management/home-manager/roles/${userConfig.role}.nix {
                          inherit pkgs lib config systemConfig;
                          user = username;
                        })
                      ];
                      home = {
                        username = username;
                        homeDirectory = "/home/${username}";
                      };
                }) systemConfig.users;
              };
            }
          ];
      };
    };
  };
}