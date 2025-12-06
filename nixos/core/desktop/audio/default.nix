# src/nixos/modules/sound/default.nix
{ config, pkgs, lib, systemConfig, ... }:

{
  imports = [
    (./. + "/${systemConfig.desktop.audio}.nix")
  ];

  # Optional: Validierung
  assertions = [
    {
      assertion = builtins.elem systemConfig.desktop.audio ["pipewire" "pulseaudio" "alsa" "none"];
      message = "Invalid audio system: ${systemConfig.desktop.audio}";
    }
  ];
  
  # Optional: Basis-Audio-Pakete
  environment.systemPackages = lib.mkIf (systemConfig.desktop.audio != "none") (with pkgs; [
    pavucontrol
    pamixer
  ]);
}