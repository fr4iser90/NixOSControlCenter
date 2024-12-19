{ config, lib, pkgs, systemConfig, ... }:

let
  # GPU configuration selection based on environment settings
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
    "none" = ./nvidia.nix;                     # Minimale Konfiguration
  };

in {
  imports = [
    (gpuConfigs.${systemConfig.gpu} or gpuConfigs.none)  # Default auf 'none' statt amdgpu
  ];

  assertions = [
    {
      assertion = builtins.hasAttr systemConfig.gpu gpuConfigs;
      message = ''
        Invalid GPU configuration: ${systemConfig.gpu}
        Available options are: ${toString (builtins.attrNames gpuConfigs)}
      '';
    }
  ];
}