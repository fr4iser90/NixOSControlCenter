# src/nixos/modules/sound/default.nix
{ config, pkgs, lib, systemConfig, ... }:

{
  imports = [
    (./. + "/${systemConfig.hardware.audio}.nix")
  ];

  # Optional: Validierung
  assertions = [
    {
      assertion = builtins.elem systemConfig.hardware.audio ["pipewire" "pulseaudio" "alsa" "none"];
      message = "Invalid audio system: ${systemConfig.hardware.audio}";
    }
  ];
  
  # Optional: Basis-Audio-Pakete
  environment.systemPackages = lib.mkIf (systemConfig.hardware.audio != "none") (with pkgs; [
    pavucontrol
    pamixer
  ]);
}