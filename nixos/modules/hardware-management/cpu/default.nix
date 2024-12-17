{ config, lib, pkgs, systemConfig, ... }:

let
  # CPU Konfigurationen basierend auf Environment Settings
  cpuConfigs = {
    # Intel Prozessoren
    "intel" = ./intel.nix;
    "intel-core" = ./intel-core.nix;
    "intel-xeon" = ./intel-xeon.nix;
    
    # AMD Prozessoren  
    "amd" = ./amd.nix;
    "amd-ryzen" = ./amd-ryzen.nix;
    "amd-epyc" = ./amd-epyc.nix;
    
    # Spezielle Konfigurationen
    "vm-cpu" = ./vm-cpu.nix;     # Für virtuelle Maschinen
    "none" = ./none.nix;         # Minimale Konfiguration
  };

in {
  imports = [
    (cpuConfigs.${systemConfig.cpu} or cpuConfigs.none)  # Default auf 'none'
  ];

  assertions = [
    {
      assertion = builtins.hasAttr systemConfig.cpu cpuConfigs;
      message = ''
        Invalid CPU configuration: ${systemConfig.cpu}
        Available options are: ${toString (builtins.attrNames cpuConfigs)}
      '';
    }
  ];
}