# NixOS ISO Configuration with Calamares and NixOS Control Center Module
# This creates a custom NixOS ISO with Calamares installer and your custom module

{ pkgs, lib, config, ... }:

let
  # Path to Calamares module
  calamaresModulePath = ./calamares-modules/nixos-control-center;
  
  # Calamares module files - packaged for ISO
  calamaresModule = pkgs.runCommand "nixos-control-center-calamares-module" {} ''
    mkdir -p $out
    cp -r ${calamaresModulePath}/* $out/
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
  
  # Calamares settings.conf with custom module
  calamaresSettings = pkgs.writeText "calamares-settings.conf" ''
    ---
    # Calamares Settings Configuration
    # This file configures Calamares installer
    
    modules-search: [ local ]
    
    sequence:
    - show:
      - welcome
      - partition
      - nixos-control-center  # Your custom module
      - users
      - summary
    - exec:
      - partition
      - nixos-control-center  # Your custom module
      - users
      - packages
      - umount
    
    branding: nixos
    
    interface:
      sidebar:
        show: true
        sidebarWidth: 200
  '';
  
  # Calamares modules.conf - register custom module
  calamaresModules = pkgs.writeText "calamares-modules.conf" ''
    ---
    # Calamares Modules Configuration
    
    nixos-control-center:
      path: /usr/lib/calamares/modules/nixos-control-center
  '';
in
{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix>
  ];

  # Allow unfree packages (needed for firmware, etc.)
  nixpkgs.config.allowUnfree = true;

  # ISO configuration
  isoImage = {
    isoName = "nixos-nixify-${config.system.nixos.version}-${pkgs.stdenv.hostPlatform.system}.iso";
    
    # Add NixOS Control Center repository to ISO
    contents = [
      {
        source = nixosControlCenterRepo;
        target = "/nixos";
      }
      # Add Calamares module to ISO
      {
        source = calamaresModule;
        target = "/usr/lib/calamares/modules/nixos-control-center";
      }
      # Add Calamares configuration
      {
        source = calamaresSettings;
        target = "/etc/calamares/settings.conf";
      }
      {
        source = calamaresModules;
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
