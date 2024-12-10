# /etc/nixos/config/configuration.nix
# Root configuration file that orchestrates all system modules
{ config, pkgs, ... }:

let
  # Import environment settings
  env = import ./env.nix;

  # Core modules that are always required
  coreModules = [
    ./hardware-configuration.nix  # Hardware scan results - DO NOT MODIFY
    ./modules/bootloader/bootloader.nix
    ./modules/networking/networking.nix
    ./modules/users/index.nix
    ./modules/packages/packages.nix
    ./modules/overlays/index.nix
    ./modules/system-services/system-services.nix
  ];

  # Optional desktop-related modules
  desktopModules = [
    ./modules/desktop
    ./modules/sound/index.nix
  ];

  # Module selection based on system type
  activeModules = 
    if env.setup == "server" 
    then coreModules
    else coreModules ++ desktopModules;

  # Validation of required modules
  validateModules = modules:
    let
      checkModule = module:
        if builtins.pathExists (toString module)
        then true
        else throw "Required module not found: ${toString module}";
    in
    map checkModule modules;

  # Ensure all required modules exist
  _ = validateModules activeModules;

in {
  # Import all active modules
  imports = activeModules;

  # Global system settings
  nixpkgs = {
    # Allow proprietary software
    config.allowUnfree = true;

    # System-wide overlay configurations (if needed)
    overlays = [
      # Add custom overlays here
    ];
  };

  # System-wide assertions
  assertions = [
    {
      assertion = env.setup == "server" -> env.desktop == null;
      message = "Server setup cannot include desktop environment";
    }
    {
      assertion = env.setup != "server" -> env.desktop != null;
      message = "Desktop setup requires desktop environment specification";
    }
  ];

  # Meta information about the configuration
  meta = {
    description = "NixOS system configuration";
    maintainers = ["${env.mainUser}"];
    # Add more metadata as needed
  };
}