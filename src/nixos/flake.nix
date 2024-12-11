# /etc/nixos/flake.nix
{
  description = "NixOS Configuration with Home Manager (Unstable Channel)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = { self, nixpkgs, home-manager, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    lib = pkgs.lib;
    env = import ./env.nix;

    # Base modules required for all systems
    baseModules = [
      (if (!env ? testing) then ./hardware-configuration.nix else {})
      ./modules/bootloader
      ./modules/networking
      ./modules/users
      ./modules/profiles  # Hier werden Profile geladen
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
          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            system.stateVersion = "unstable";
            
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              
              users = lib.mapAttrs (username: userConfig: 
                  { config, ... }: {  # Wichtig: Wir fügen hier die Modul-Argumente hinzu
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