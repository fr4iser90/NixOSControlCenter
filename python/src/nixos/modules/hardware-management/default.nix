# src/nixos/modules/hardware-management/default.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  # GPU configuration selection based on environment settings
  gpuConfigs = {
    nvidia = ./gpu/nvidia.nix;
    nvidiaIntelPrime = ./gpu/nvidiaIntelPrime.nix;
    intel = ./gpu/intel.nix;
    amdgpu = ./gpu/amd.nix;
  };

in {
  imports = [
    (gpuConfigs.${systemConfig.gpu} or gpuConfigs.amdgpu)
  ];

  assertions = [
    {
      assertion = builtins.hasAttr systemConfig.gpu gpuConfigs;
      message = "Invalid GPU configuration: ${systemConfig.gpu}";
    }
    # Weitere Hardware-bezogene Assertions können hier hinzugefügt werden
    {
      assertion = builtins.elem systemConfig.audio ["pulseaudio" "pipewire" "none"];
      message = "Invalid audio configuration: ${systemConfig.audio}";
    }
  ];
}