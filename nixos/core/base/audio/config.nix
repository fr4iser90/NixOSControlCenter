{ config, lib, pkgs, getModuleConfig, ... }:
let
  cfg = getModuleConfig "audio";
in
{
  config = {
    assertions = lib.mkIf (cfg.enable or false) [
      {
        assertion = builtins.elem (cfg.system or "none") ["pipewire" "pulseaudio" "alsa" "none"];
        message = "Invalid audio system: ${cfg.system or "none"}";
      }
    ];

    environment.systemPackages = lib.mkIf (cfg.enable or false && (cfg.system or "none") != "none") [
      pkgs.pavucontrol
      pkgs.pamixer
    ];
  };
}
