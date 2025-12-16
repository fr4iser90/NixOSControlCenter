{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.core.management.system-manager.submodules.system-update or {};
in {
  imports = [
    ./options.nix
  ] ++ (if (cfg.enable or true) then [
    ./commands.nix  # System update commands
    ./config.nix    # System update implementation
    ./handlers/system-update.nix  # System update handler
  ] else []);
}
