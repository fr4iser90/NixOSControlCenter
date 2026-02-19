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
  ] ++ (if (cfg.enable or false) then [
    ./commands.nix
    ./config.nix
  ] else []);
}
