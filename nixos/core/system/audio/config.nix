{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.audio or {};
  # CRITICAL: Use absolute path to deployed location, not relative (which resolves to store)
  userConfigFile = "/etc/nixos/core/system/audio/audio-config.nix";
  symlinkPath = "/etc/nixos/configs/audio-config.nix";
  configHelpers = import ../../management/system-manager/lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../../management/system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
  defaultConfig = ''
{
  audio = {
    enable = true;
    system = "pipewire";
  };
}
'';
in
{
  config = lib.mkMerge [
    {
      # Create symlink on activation (always, not only when enabled)
      # Uses central API from system-manager (professional pattern)
      system.activationScripts.audio-config-symlink = 
        configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig;
    }
    (lib.mkIf (cfg.enable or false) {
      # Validation
      assertions = [
        {
          assertion = builtins.elem (cfg.system or "none") ["pipewire" "pulseaudio" "alsa" "none"];
          message = "Invalid audio system: ${cfg.system or "none"}";
        }
      ];
      
      # Base audio packages
      environment.systemPackages = lib.mkIf ((cfg.system or "none") != "none") (with pkgs; [
        pavucontrol
        pamixer
      ]);
    })
  ];
}
