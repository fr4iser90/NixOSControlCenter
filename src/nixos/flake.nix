{
  description = "NixOS Configuration with Home Manager (Unstable Only)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # Nur die instabile Version
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = { self, nixpkgs, home-manager, ... }: let
    system = "x86_64-linux"; 

    # Importiere nur nixpkgs-unstable
    pkgs = import nixpkgs { inherit system; };
    lib = pkgs.lib;

    # Umgebungsvariablen aus env.nix laden
    env = import ./env.nix;

    # Home-Manager-Modul für Benutzer
    userModule = user: { config, ... }: import ./modules/homemanager/home-${user}.nix { 
      inherit pkgs lib config home-manager;
      user = user; 
    };

  in {
    nixosConfigurations = {
      "${env.hostName}" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            system.stateVersion = "unstable";  # oder "24.11" wenn Sie eine spezifische Version wollen
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users = lib.recursiveUpdate {
              "${env.mainUser}" = userModule env.mainUser;
            } (lib.optionalAttrs (env.guestUser != "") {
              "${env.guestUser}" = userModule env.guestUser;
            });
          }
        ];
      };
    };
  };
}
