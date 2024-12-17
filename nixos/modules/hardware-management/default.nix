{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./gpu
    ./cpu
  ];

  assertions = [
    {
      assertion = builtins.elem systemConfig.audio ["pulseaudio" "pipewire" "none"];
      message = "Invalid audio configuration: ${systemConfig.audio}";
    }
    # Weitere allgemeine Hardware-Assertions hier...
  ];
}