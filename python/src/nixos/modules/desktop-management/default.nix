#/etc/nixos/modules/desktop/default.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../env.nix;

  # GPU configuration selection based on environment settings
  gpuConfigs = {
#    nvidia = ./hardware/gpu/nvidia.nix;
#    nvidiaIntelPrime = ./hardware/gpu/nvidiaIntelPrime.nix;
#    intel = ./hardware/gpu/intel.nix;
    amdgpu = ./hardware/gpu/amdgpu.nix;
  };

  # Select GPU configuration or default to amdgpu
  gpuConfig = import (gpuConfigs.${env.gpu} or gpuConfigs.amdgpu) { 
    inherit config pkgs; 
  };

in {
  imports = [ 
    gpuConfig 
#    ./display/x11
    ./display/wayland
    ./managers/display
    ./managers/desktop
#    ./themes
  ];

  # DBus-Fix
  services.dbus = {
    enable = true;
    implementation = "broker";
  };

  # X Server configuration
  services.xserver = {
    enable = true;
    xkb = {
      layout = env.keyboardLayout;
      options = env.keyboardOptions;
    };
  };

  assertions = [
    {
      assertion = builtins.hasAttr env.gpu gpuConfigs;
      message = "Invalid GPU configuration: ${env.gpu}";
    }
  ];
}




