{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Same pattern as GPU/memory — never use systemConfig.hardware.* (wrong path)
  hardwareCfg = getModuleConfig "hardware";
  cpuType = hardwareCfg.cpu or "none";

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
    (cpuConfigs.${cpuType})
  ];

  assertions = [
    {
      assertion = builtins.hasAttr cpuType cpuConfigs;
      message = ''
        Invalid CPU configuration: ${cpuType}
        Available options are: ${toString (builtins.attrNames cpuConfigs)}
      '';
    }
  ];
}
