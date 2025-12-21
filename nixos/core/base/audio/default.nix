{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "audio";
in {
  _module.metadata = {
    role = "core";
    name = "audio";
    description = "Audio system configuration and management";
    category = "base";
    subcategory = "audio";
    version = "1.0.0";
  };

  imports = if cfg.enable or false then [
    ./options.nix
  ] ++ (if (cfg.system or "none") != "none" then [
    (./providers + "/${cfg.system}.nix")
    ./config.nix
  ] else [
    ./config.nix
  ]) else [];
}
