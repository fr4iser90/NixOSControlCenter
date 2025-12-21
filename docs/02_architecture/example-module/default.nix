{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.modules.example-module or {};
in {
  imports = [
    ./options.nix
  ] ++ (if (cfg.enable or false) then [
    # Import sub-modules only when enabled
    # ./sub-module-1
    # ./sub-module-2
    ./config.nix
  ] else [
    # Always import config.nix (for symlink management even when disabled)
    ./config.nix
  ]);
}

