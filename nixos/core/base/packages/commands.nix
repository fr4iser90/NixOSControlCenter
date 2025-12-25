{ config, lib, pkgs, getModuleConfig, moduleName, ... }:
let
  cfg = getModuleConfig moduleName;
in
  lib.mkIf (cfg.enable or true) {
    # TODO: Add package management commands?
    # - ncc package-list
    # - ncc package-install
    # - ncc package-update
  }