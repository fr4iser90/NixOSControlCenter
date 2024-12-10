{
  description = "NixOS Configuration with Home Manager (Unstable Channel)";

  # Define all external dependencies
  inputs = {
    # Use only unstable channel for consistent package versions
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Home Manager for user environment management
    home-manager.url = "github:nix-community/home-manager";
  };

  # System configuration and outputs
  outputs = { self, nixpkgs, home-manager, ... }: let
    # System architecture definition
    system = "x86_64-linux";

    # Import nixpkgs with system architecture
    pkgs = import nixpkgs { inherit system; };
    lib = pkgs.lib;

    # Load environment configuration from env.nix
    env = import ./env.nix;

    # Function to generate Home Manager configuration for a user
    # Takes a username and returns a module with user-specific settings
    userModule = user: { config, ... }: 
      import ./modules/homemanager/home-${user}.nix { 
        inherit pkgs lib config home-manager;
        user = user; 
      };

  in {
    # NixOS system configurations
    nixosConfigurations = {
      # Create configuration based on hostname from env.nix
      "${env.hostName}" = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          # Base system configuration
          ./configuration.nix

          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            # System state version (consider pinning to specific version)
            system.stateVersion = "unstable";

            # Home Manager configuration
            home-manager = {
              useGlobalPkgs = true;      # Use system-level packages
              useUserPackages = true;     # Enable per-user package management
              
              # User configurations
              users = lib.recursiveUpdate 
                # Main user configuration (always present)
                {
                  "${env.mainUser}" = userModule env.mainUser;
                }
                # Guest user configuration (optional)
                (lib.optionalAttrs (env.guestUser != "") {
                  "${env.guestUser}" = userModule env.guestUser;
                });
            };
          }
        ];
      };
    };
  };
}