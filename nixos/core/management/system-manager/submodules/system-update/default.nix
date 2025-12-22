{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = getModuleConfig "system-update";
in {
  imports = [
    ./options.nix
  ] ++ (if (cfg.enable or true) then [
    ./commands.nix  # System update commands
    ./config.nix    # System update implementation
    ./handlers/system-update.nix  # System update handler
  ] else []);
}
