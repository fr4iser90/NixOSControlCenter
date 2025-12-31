{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # GPU configuration selection based on environment settings
  hardwareCfg = getModuleConfig "hardware";
  gpuConfigs = {
    # Single GPU configurations
    "nvidia" = ./nvidia.nix;
    "amd" = ./amd.nix;
    "intel" = ./intel.nix;
    
    # Hybrid configurations
    "nvidia-intel" = ./nvidia-intel.nix;  # früher nvidiaIntelPrime
    "nvidia-amd" = ./nvidia-amd.nix;
    "intel-igpu" = ./intel-igpu.nix;      # Intel Integrated Graphics
    
    # Multi-GPU configurations
    "nvidia-sli" = ./nvidia-sli.nix;
    "amd-crossfire" = ./amd-crossfire.nix;
    
    # Special configurations
    "nvidia-optimus" = ./nvidia-optimus.nix;  # Laptop-spezifisch
    "vm-gpu" = ./vm-gpu.nix;                 # Für virtuelle Maschinen
    "none" = ./none.nix;                     # Minimale Konfiguration
    "amd-intel" = ./intel.nix;
    
    # Virtual Machine configs
    "qxl-virtual" = ./vm-gpu.nix;
    "virtio-virtual" = ./vm-gpu.nix;
    "basic-virtual" = ./vm-gpu.nix;
    
    # Add the dual AMD configuration
    "amd-amd" = ./amd-amd.nix;
  };

in {
  imports = [
    (gpuConfigs.${hardwareCfg.gpu or "none"})
  ];

  assertions = [
    {
      assertion = builtins.hasAttr (hardwareCfg.gpu or "none") gpuConfigs;
      message = ''
        Invalid GPU configuration: ${hardwareCfg.gpu or "none"}
        Available options are: ${toString (builtins.attrNames gpuConfigs)}
      '';
    }
  ];
}