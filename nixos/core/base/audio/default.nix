{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = baseNameOf ./. ;  # ← audio aus core/base/audio/
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Audio system configuration and management";
    category = "base";
    subcategory = "audio";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  imports = if cfg.enable or false then [
    ./options.nix
  ] ++ (if (cfg.system or "none") != "none" then [
    (./handlers + "/${cfg.system}.nix")
    (import ./config.nix { inherit config lib pkgs getModuleConfig moduleName; })
  ] else [
    (import ./config.nix { inherit config lib pkgs getModuleConfig moduleName; })
  ]) else [];
}
