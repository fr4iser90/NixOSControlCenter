# NixOS ISO Configuration with Calamares and NixOS Control Center Module
# This creates a custom NixOS ISO with Calamares installer and your custom module

{ pkgs, lib, config, ... }:

let
  # Path to Calamares modules
  calamaresModulePath = ./calamares-modules/nixos-control-center;
  calamaresJobModulePath = ./calamares-modules/nixos-control-center-job;
  
  # Calamares GUI module files - packaged for ISO
  calamaresModule = pkgs.runCommand "nixos-control-center-calamares-module" {} ''
    mkdir -p $out
    cp -r ${calamaresModulePath}/* $out/
    chmod -R u+w $out
  '';
  
  # Calamares job module files - packaged for ISO
  calamaresJobModule = pkgs.runCommand "nixos-control-center-job-calamares-module" {} ''
    mkdir -p $out
    cp -r ${calamaresJobModulePath}/* $out/
    chmod -R u+w $out
  '';
  
  # NixOS Control Center repository (will be copied to ISO)
  # Get repo root (assuming we're in nixos/modules/specialized/nixify/iso-builder)
  repoRoot = builtins.path {
    path = ../../../../..;
    filter = path: type:
      type == "directory" || 
      (type == "regular" && !(builtins.match ".*\\.git.*" path != null));
  };
  
  nixosControlCenterRepo = pkgs.runCommand "nixos-control-center-repo" {} ''
    mkdir -p $out
    cp -r ${repoRoot}/* $out/ 2>/dev/null || true
    # Remove build artifacts and git
    rm -rf $out/.git $out/result $out/result-* $out/*.iso 2>/dev/null || true
    chmod -R u+w $out
  '';
  
  # Merge Calamares config at BUILD TIME (not runtime)
  # This creates a merged config based on the standard NixOS Calamares sequence
  # The standard sequence is: welcome, locale, keyboard, users, packagechooser, notesqml@unfree, partition, summary
  mergedCalamaresSettings = pkgs.writeText "calamares-settings.conf" ''
---
# Calamares Settings Configuration
# Merged with NixOS Control Center module

modules-search: [ local ]

sequence:
- show:
  - welcome
  - locale
  - keyboard
  - users
  - packagechooser
  - notesqml@unfree
  - partition
  - nixos-control-center  # Our custom GUI module
  - summary
- exec:
  - partition
  - mount
  - nixos  # Calamares generates configuration.nix here
  - nixos-control-center-job  # Our custom job module modifies the config
  - users
  - umount
- show:
  - finished

branding: nixos

interface:
  sidebar:
    show: true
    sidebarWidth: 200
'';
  
  # Merge Calamares modules.conf at BUILD TIME
  # Standard modules are auto-discovered by Calamares, we only need to register our custom modules
  mergedCalamaresModules = pkgs.writeText "calamares-modules.conf" ''
---
# Calamares Modules Configuration
# Standard modules are auto-discovered, we only register our custom modules

nixos-control-center:
  path: /usr/lib/calamares/modules/nixos-control-center

nixos-control-center-job:
  path: /usr/lib/calamares/modules/nixos-control-center-job
'';
  
  # Desktop Environment Selection
  # Options: "gnome", "plasma6", "xfce"
  # Change this to switch between desktop environments
  desktopEnv = "plasma6";  # Default: KDE Plasma 6
  
  # Select base ISO based on desktop environment
  baseIsoModule = 
    if desktopEnv == "gnome" then
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix>
    else if desktopEnv == "plasma6" then
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix>
    else if desktopEnv == "xfce" then
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-xfce.nix>
    else
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix>;  # Default fallback
in
{
  imports = [
    baseIsoModule
  ];

  # Allow unfree packages (needed for firmware, etc.)
  nixpkgs.config.allowUnfree = true;

  # ISO configuration
  # Set baseName to control the ISO filename (isoName is derived from baseName)
  # Include desktop environment in name for clarity
  image = {
    baseName = lib.mkForce "nixos-nixify-${desktopEnv}-${config.system.nixos.version}-${pkgs.stdenv.hostPlatform.system}";
  };
  
  isoImage = {
    
    # Add NixOS Control Center repository to ISO
    contents = [
      {
        source = nixosControlCenterRepo;
        target = "/nixos";
      }
      # Add Calamares GUI module to ISO
      {
        source = calamaresModule;
        target = "/usr/lib/calamares/modules/nixos-control-center";
      }
      # Add Calamares job module to ISO
      {
        source = calamaresJobModule;
        target = "/usr/lib/calamares/modules/nixos-control-center-job";
      }
      # Add merged Calamares settings (built at build time, not runtime)
      {
        source = mergedCalamaresSettings;
        target = "/etc/calamares/settings.conf";
      }
      # Add merged Calamares modules.conf
      {
        source = mergedCalamaresModules;
        target = "/etc/calamares/modules.conf";
      }
    ];
    
    # Make repository accessible from installer
    makeEfiBootable = true;
    makeUsbBootable = true;
  };

  # System packages needed for Calamares module
  environment.systemPackages = with pkgs; [
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
  ];

  # Enable services needed for hardware detection
  services.udev.enable = true;
  hardware.enableAllFirmware = true;
}
