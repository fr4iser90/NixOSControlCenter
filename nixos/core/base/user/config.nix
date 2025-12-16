{ config, lib, getModuleConfig, ... }:
let
  cfg = getModuleConfig "user";
in
{
  # User module implementation is handled in default.nix
}
