{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;  # "nixify"
  cfg = getModuleConfig moduleName;
in
{
  _module.args = {
    nixifyCfg = cfg;
    nixifyModuleName = moduleName;  # EINMAL berechnet, eindeutiger Name!
  };

  imports = [
    ./options.nix
    ./commands.nix
  ] ++ (if (cfg.enable or false) then [
    ./config.nix
  ] else []);
}
