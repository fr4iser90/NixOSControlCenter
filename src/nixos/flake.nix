{
  description = "NixOS Configuration with Home Manager (Unstable Channel)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = { self, nixpkgs, home-manager, ... }: let
    system = "x86_64-linux";
    env = import ./env.nix;
    
    pkgs = import nixpkgs { 
      inherit system;
      config.allowUnfree = env.allowUnfree or false;
    };
    lib = pkgs.lib;

    # Base modules required for all systems
    baseModules = [
      ./hardware-configuration.nix
      ./modules/bootloader
      ./modules/networking
      ./modules/users
      ./modules/profiles
      ./modules/nix
      ./modules/reporting
    ];

    # Desktop-specific modules
    desktopModules = [
      ./modules/desktop
      ./modules/sound/index.nix
    ];

  in {
    nixosConfigurations = {
      "${env.hostName}" = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = baseModules ++ [      
          # Unfree Konfiguration
          {
            nixpkgs.config = {
              allowUnfree = env.allowUnfree or false;
            };
          }

          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            system.stateVersion = "unstable";
            
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users = lib.mapAttrs (username: userConfig: 
                  { config, ... }: {
                    imports = [ 
                      (import ./modules/homemanager/roles/${userConfig.role}.nix {
                        inherit pkgs lib config;
                        user = username;
                      })
                    ];
                    home = {
                      username = username;
                      homeDirectory = "/home/${username}";
                    };
              }) env.users;
            };
          }
        ];
      };
    };
  };
}