# configuration.nix
{ config, pkgs, ... }:

let
  env = import ./env.nix;
  profileTypes = import ./modules/profiles/types;
  
  # Validate system type across all categories
  isValidType = type:
    let
      categories = ["server" "desktop" "hybrid"];
      hasType = category: 
        builtins.hasAttr type (profileTypes.systemTypes.${category} or {});
    in builtins.any hasType categories;

  # Base modules required for all systems
  baseModules = [
    ./hardware-configuration.nix
    ./modules/bootloader
    ./modules/networking
    ./modules/users/index.nix
   # ./modules/security
   # ./modules/overlays
  ];

  # Desktop-specific modules
  desktopModules = [
    ./modules/desktop
    ./modules/sound/index.nix
  ];

  # Profile-specific modules
  profileModules = [
    ./modules/profiles
  ];

  # Determine profile category based on system type
  profileCategory = 
    if builtins.hasAttr env.systemType (profileTypes.systemTypes.desktop or {}) then "desktop"
    else if builtins.hasAttr env.systemType (profileTypes.systemTypes.server or {}) then "server"
    else if builtins.hasAttr env.systemType (profileTypes.systemTypes.hybrid or {}) then "hybrid"
    else throw "Unknown profile category for ${env.systemType}";

  # Load the corresponding profile configuration
  profile = profileTypes.systemTypes.${profileCategory}.${env.systemType} or
    (throw "Invalid system type: ${env.systemType}");

  # Determine which modules to load based on profile
  additionalModules = 
    if profile.defaults.desktop or false
    then desktopModules
    else [];

in {
  # Import all required modules based on profile
  imports = baseModules ++ profileModules ++ additionalModules;

  # System validations
  assertions = [
    {
      # Ensure system type is valid
      assertion = isValidType env.systemType;
      message = "Invalid system type: ${env.systemType}";
    }
    {
      # Ensure desktop environment is set when required
      assertion = (profile.defaults.desktop or false) -> (env.desktop != null);
      message = "Desktop environment required for this system type";
    }
  ];

  # Allow unfree packages globally
  nixpkgs.config.allowUnfree = true;
}
