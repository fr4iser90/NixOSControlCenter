{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.audio or {};
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./audio-config.nix;
in
{
  config = lib.mkMerge [
    # Create config on activation (always runs)
    # Uses new external config system
    (configHelpers.createModuleConfig {
      moduleName = "audio";
      defaultConfig = defaultConfig;
    })
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
