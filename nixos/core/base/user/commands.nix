{ config, lib, pkgs, systemConfig, getCurrentModuleMetadata, ... }:
let
  # Use dynamic config access like other modules
  metadata = getCurrentModuleMetadata ./.;  # ← Wie in options.nix!
  cfg = systemConfig.${metadata.configPath};
in
  lib.mkIf (cfg.enable or true) {
    # TODO: Add user management commands?
    # - ncc user-create
    # - ncc user-delete
    # - ncc user-list
    # - ncc user-modify
  }
