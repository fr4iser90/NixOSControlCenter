{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.desktop or {};
in {
  # imports must be at top level
  imports = if (cfg.enable or false) then [ 
    ./display-managers
    ./display-servers
    ./environments
    ./themes
    ./config.nix  # Implementation logic (symlink management + desktop config)
  ] else [
    ./config.nix  # Import even if disabled (for symlink management)
  ];
}