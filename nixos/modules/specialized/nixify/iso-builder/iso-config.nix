# NixOS ISO Configuration with Calamares and NixOS Control Center Module
# This creates a custom NixOS ISO with Calamares installer and your custom module

{ pkgs, lib, config, desktopEnv, ... }:

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
  # We extend the base config from calamares-nixos-extensions by adding our custom module
  # The base config is in pkgs.calamares-nixos-extensions/etc/calamares/settings.conf
  baseCalamaresSettings = "${pkgs.calamares-nixos-extensions}/etc/calamares/settings.conf";
  
  # Create merged settings.conf that extends the base config
  # We use a Python script to properly merge YAML and insert our module
  mergedCalamaresSettings = pkgs.runCommand "calamares-settings-merged" {
    nativeBuildInputs = [ pkgs.python3Packages.pyyaml ];
  } ''
    # Read base config
    BASE_CONFIG="${baseCalamaresSettings}"
    
    # Use Python to merge YAML and insert our module
    ${pkgs.python3}/bin/python3 <<EOF
import yaml
import sys

# Read base config
with open("$BASE_CONFIG", 'r') as f:
    config = yaml.safe_load(f)

# Insert our module before "summary" in the show sequence
if 'sequence' in config and isinstance(config['sequence'], list):
    for phase in config['sequence']:
        if isinstance(phase, dict) and 'show' in phase:
            show_list = phase['show']
            if 'summary' in show_list:
                summary_idx = show_list.index('summary')
                if 'nixos-control-center' not in show_list:
                    show_list.insert(summary_idx, 'nixos-control-center')
            elif 'nixos-control-center' not in show_list:
                show_list.append('nixos-control-center')
        
        if isinstance(phase, dict) and 'exec' in phase:
            exec_list = phase['exec']
            if 'nixos' in exec_list:
                nixos_idx = exec_list.index('nixos')
                if 'nixos-control-center-job' not in exec_list:
                    exec_list.insert(nixos_idx + 1, 'nixos-control-center-job')
            elif 'nixos-control-center-job' not in exec_list:
                exec_list.append('nixos-control-center-job')

# Write merged config
with open("$out", 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
EOF
  '';
  
  # Merge Calamares modules.conf at BUILD TIME
  # The base config might not have a modules.conf (modules are auto-discovered)
  # We create one that registers our custom modules
  mergedCalamaresModules = pkgs.writeText "calamares-modules.conf" ''
---
# Calamares Modules Configuration
# Standard modules are auto-discovered by Calamares, we only register our custom modules

nixos-control-center:
  path: /usr/lib/calamares/modules/nixos-control-center

nixos-control-center-job:
  path: /usr/lib/calamares/modules/nixos-control-center-job
'';
  
  # Select base ISO based on desktop environment
  # desktopEnv is passed as specialArg from build-iso-*.nix scripts (required, no default)
  baseIsoModule = 
    if desktopEnv == "gnome" then
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix>
    else if desktopEnv == "plasma6" then
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix>
    else
      throw "Unknown desktop environment: ${desktopEnv}. Supported: gnome, plasma6";
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
