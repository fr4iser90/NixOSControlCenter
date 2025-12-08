{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.audio or {};
  # CRITICAL: Use absolute path to deployed location, not relative (which resolves to store)
  userConfigFile = "/etc/nixos/core/audio/user-configs/audio-config.nix";
  symlinkPath = "/etc/nixos/configs/audio-config.nix";
  # Use API (like cli-formatter.api)
  configHelpers = config.core.management.system-manager.api.configHelpers;
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
