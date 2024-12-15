# src/nixos/modules/sound/default.nix
{ config, pkgs, lib, systemConfig, ... }:

{
  imports = [
    (./. + "/${systemConfig.audio}.nix")
  ];

  # Optional: Validierung
  assertions = [
    {
      assertion = builtins.elem systemConfig.audio ["pipewire" "pulseaudio" "alsa" "none"];
      message = "Invalid audio system: ${systemConfig.audio}";
    }
  ];
  
  # Optional: Basis-Audio-Pakete
  environment.systemPackages = lib.mkIf (systemConfig.audio != "none") (with pkgs; [
#    pavucontrol
#    pamixer
  ]);
}