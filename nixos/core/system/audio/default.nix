{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.audio or {};
in {
  imports = [
    ./options.nix
  ] ++ (if (cfg.enable or false) && (cfg.system or "none") != "none" then [
    (./providers + "/${cfg.system}.nix")
    ./config.nix
  ] else [
    ./config.nix
  ]);
}
