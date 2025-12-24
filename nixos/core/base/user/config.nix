{ config, lib, getModuleConfig, moduleName, ... }:
let
  cfg = getModuleConfig moduleName;
in
{
  # User module implementation is handled in default.nix
}
