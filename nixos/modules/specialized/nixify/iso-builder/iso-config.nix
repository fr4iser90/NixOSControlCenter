# NixOS ISO Configuration with Calamares and NixOS Control Center Module
# This creates a custom NixOS ISO with Calamares installer and your custom module

{ pkgs, lib, config, desktopEnv, ... }:

let
  # NixOS Control Center repository (will be copied to ISO)
  # Get nixos/ directory (assuming we're in nixos/modules/specialized/nixify/iso-builder)
  # 4 levels up = nixos/ directory
  nixosDir = builtins.path {
    path = ../../../..;
    filter = path: type:
      type == "directory" || 
      (type == "regular" && !(builtins.match ".*\\.git.*" path != null));
  };
  
  # Get shell/ directory from repository root
  # 5 levels up = Repository-Root, then shell/
  shellDir = builtins.path {
    path = ../../../../../shell;
    filter = path: type:
      type == "directory" || 
      (type == "regular" && !(builtins.match ".*\\.git.*" path != null));
  };
  
  nixosControlCenterRepo = pkgs.runCommand "nixos-control-center-repo" {} ''
    mkdir -p $out
    # Copy nixos/ directory
    cp -r ${nixosDir}/* $out/ 2>/dev/null || true
    # Copy shell/ directory
    mkdir -p $out/shell
    cp -r ${shellDir}/* $out/shell/ 2>/dev/null || true
    # Remove build artifacts and git
    rm -rf $out/.git $out/result $out/result-* $out/*.iso 2>/dev/null || true
    chmod -R u+w $out
  '';
  
  # Module derivations are now defined in calamares-overlay.nix
  # Reference them from pkgs (which has the overlay applied)
  calamaresModule = pkgs.calamaresModule;
  calamaresJobModule = pkgs.calamaresJobModule;
  
  # mergedCalamaresModules is also created in the overlay
  # We need to get it from the patched calamares-nixos-extensions package
  # Actually, we'll create it here using the module derivations from pkgs
  mergedCalamaresModules = pkgs.writeText "calamares-modules.conf" ''
---
# Calamares Modules Configuration
# Modules are loaded directly from Nix store paths

nixos-control-center:
  path: "${toString calamaresModule}"

nixos-control-center-job:
  path: "${toString calamaresJobModule}"
'';
  
  # Select base ISO based on desktop environment
  # desktopEnv is passed as specialArg from build-iso-*.nix scripts (required, no default)
  baseIsoModule = 
    if desktopEnv == "gnome" then
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix>
    else if desktopEnv == "plasma6" then
      ./base-iso-patched.nix  # Use patched version that uses local installation-cd-graphical-calamares.nix
    else
      throw "Unknown desktop environment: ${desktopEnv}. Supported: gnome, plasma6";
in
{
  # CRITICAL: Overlay is now applied in build-iso-plasma6.nix BEFORE eval-config.nix
  # This ensures only ONE nixpkgs instance exists → only ONE calamares-nixos-extensions
  # No need to import overlay module here, pkgs is already overlay-applied
  # CRITICAL: nixpkgs.config.allowUnfree is set in build-iso-plasma6.nix when creating pkgs
  # Cannot set it here because pkgs is externally created
  imports = [
    baseIsoModule
  ];

  # ISO configuration
  # Set baseName to control the ISO filename (isoName is derived from baseName)
  # Include desktop environment in name for clarity
  image = {
    baseName = lib.mkForce "nixos-nixify-${desktopEnv}-${config.system.nixos.version}-${pkgs.stdenv.hostPlatform.system}";
  };
  
  # CRITICAL: Use environment.etc to create /etc/calamares/modules.conf in the live system
  # isoImage.contents only copies to ISO filesystem, not to live system's tmpfs
  # environment.etc creates files in /etc at boot time in the live system
  environment.etc."calamares/modules.conf" = {
    source = mergedCalamaresModules;
    mode = "0644";
  };

  isoImage = {
    
    # Use lib.mkAfter to append to baseIsoModule's contents
    contents = lib.mkAfter [
      {
        source = nixosControlCenterRepo;
        target = "/nixos";
      }
    ];
    
    # CRITICAL: Use lib.mkAfter to APPEND to baseIsoModule's storeContents
    # Do NOT overwrite, as baseIsoModule already includes system.build.toplevel
    # This ensures both the base storeContents AND our custom derivations are included
    storeContents = lib.mkAfter [
      nixosControlCenterRepo
      calamaresModule
      calamaresJobModule
      mergedCalamaresModules
    ];
    
    # Make repository accessible from installer
    makeEfiBootable = true;
    makeUsbBootable = true;
  };
  
  # CRITICAL: Falls storeContents allein nicht funktioniert,
  # zwinge die ISO-Derivation, direkt von unseren Derivationen abzuhängen
  # Dies macht die Derivationen zu direkten Dependencies der ISO
  # Community-Lösung: overrideAttrs auf der Derivation selbst
  # WICHTIG: Wir müssen dies NACH der Definition von isoImage machen,
  # daher verwenden wir lib.mkOverride mit hoher Priorität
  system.build.isoImage = lib.mkOverride 1000 (
    (config.system.build.isoImage).overrideAttrs (old: {
      buildInputs = (old.buildInputs or []) ++ [
        nixosControlCenterRepo
        calamaresModule
        calamaresJobModule
        mergedCalamaresModules
      ];
    })
  );

  # System packages needed for Calamares module
  # CRITICAL: Also include custom directory derivations to force them as dependencies
  # Note: Files (mergedCalamaresSettings, mergedCalamaresModules) cannot be in systemPackages
  # They are already referenced in isoImage.contents and will be built as dependencies
  environment.systemPackages = with pkgs; lib.mkAfter [
    # Python dependencies for Calamares module
    python3
    python3Packages.pyqt5
    
    # Tools for hardware checks
    pciutils  # lspci for GPU detection
    usbutils  # lsusb
    dmidecode  # Hardware info
    
    # NixOS Control Center dependencies
    bash
    git
    nix
    
    # CRITICAL: Explicitly reference calamares-nixos-extensions to ensure overlay is applied
    # This forces the overlay to be evaluated for this package, ensuring modules.conf is included
    # Without this, baseIsoModule might use the unpatched version before overlay is applied
    # NOTE: We use pkgs. explicitly here to ensure overlay is applied
    pkgs.calamares-nixos-extensions
    
    # CRITICAL: Force evaluation of custom directory derivations by adding them to systemPackages
    # This ensures they are built and available, even though they're also in isoImage.contents
    # The ISO builder will copy them from the store paths referenced in contents
    # Note: Only directories can be in systemPackages, not files
    # Modules are loaded directly from Store paths via modules.conf - no copying needed
    nixosControlCenterRepo
    calamaresModule
    calamaresJobModule
  ];

  # Enable services needed for hardware detection
  services.udev.enable = true;
  hardware.enableAllFirmware = true;
  
}
