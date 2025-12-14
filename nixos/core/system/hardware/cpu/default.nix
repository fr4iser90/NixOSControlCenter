{ config, lib, pkgs, systemConfig, ... }:

let
  # CPU Konfigurationen basierend auf Environment Settings
  cpuConfigs = {
    # Intel Prozessoren
    "intel" = ./intel.nix;
    "intel-core" = ./intel.nix;
    "intel-xeon" = ./intel.nix;
    
    # AMD Prozessoren  
    "amd" = ./amd.nix;
    "amd-ryzen" = ./amd.nix;
    "amd-epyc" = ./amd.nix;
    
    # Spezielle Konfigurationen
    "vm-cpu" = ./vm-cpu.nix;     # Für virtuelle Maschinen
    "none" = ./none.nix;         # Minimale Konfiguration
  };

in {
  imports = [
    (cpuConfigs.${systemConfig.hardware.cpu or "none"})
  ];

  assertions = [
    {
      assertion = builtins.hasAttr (systemConfig.hardware.cpu or "none") cpuConfigs;
      message = ''
        Invalid CPU configuration: ${systemConfig.hardware.cpu or "none"}
        Available options are: ${toString (builtins.attrNames cpuConfigs)}
      '';
    }
  ];
}