{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.audio or {};
  userConfigFile = ./user-configs/audio-config.nix;
  symlinkPath = "/etc/nixos/configs/audio-config.nix";
in {
  # imports must be at top level
  imports = if (cfg.enable or false) && (cfg.system or "none") != "none" then [
    (./. + "/${cfg.system}.nix")
    ./config.nix  # Implementation logic (symlink management + audio config)
  ] else [
    ./config.nix  # Import even if disabled (for symlink management)
  ];
}
