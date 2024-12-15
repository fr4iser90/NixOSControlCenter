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
      ./modules/boot-management
      ./modules/network-management
      ./modules/user-management
      ./modules/profile-management
      ./modules/nix-management
      ./modules/log-management
    ];

    # Desktop-specific modules
    desktopModules = [
      ./modules/desktop-management
      ./modules/audio-management
    ];

  in {
    nixosConfigurations = {
      "${env.hostName}" = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = baseModules ++ 
          (if env.desktop != null then desktopModules else []) ++ 
          [      
            # Unfree Konfiguration
            {
              nixpkgs.config = {
                allowUnfree = env.allowUnfree or false;
              };
            }

            # Home Manager integration
            home-manager.nixosModules.home-manager
            {
              #system.stateVersion = "24.05"; # Deprecated
              #system.stateVersion = "24.05"; # stable Vicuna
              system.stateVersion = "25.05"; #  unstable Warbler
              
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users = lib.mapAttrs (username: userConfig: 
                    { config, ... }: {
                      imports = [ 
                        (import ./modules/user-management/home-manager/roles/${userConfig.role}.nix {
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