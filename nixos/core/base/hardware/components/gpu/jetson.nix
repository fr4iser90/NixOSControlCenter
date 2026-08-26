# NVIDIA Jetson intent via systemConfig (gpu = "jetson").
# Jetpack itself stays a *host flake extra* — detected/preserved by ncc-check-flake-extras.
# Fixture/test: tests/hardware/jetson/test-flake-extras-jetson.sh (not the generic extras suite).
# Only set nvidia-jetpack options when that module is already imported by the host flake.
{ config, lib, pkgs, options, getModuleConfig, ... }:

let
  cfg = getModuleConfig "hardware";
  jp = cfg.jetpack or { };
  som = jp.som or "orin-nano";
  carrierBoard = jp.carrierBoard or "devkit";
  super = jp.super or true;
  containerToolkit = jp.containerToolkit or true;
  nvpmodelProfile = jp.nvpmodelProfile or null;
  onAarch64 = pkgs.stdenv.hostPlatform.isAarch64;
  hasJetpack = lib.hasAttr "nvidia-jetpack" options.hardware;

  jetpackConfig = if hasJetpack then {
    hardware.nvidia-jetpack = {
      enable = true;
      inherit som carrierBoard super;
    };
    hardware.nvidia-container-toolkit.enable = containerToolkit;
    virtualisation.docker.enableNvidia = lib.mkIf containerToolkit (lib.mkOverride 40 true);
    services.nvpmodel.profileNumber = lib.mkIf (nvpmodelProfile != null) nvpmodelProfile;
  } else {};
in
lib.mkIf onAarch64 (
  lib.mkMerge [
    { hardware.graphics.enable = true; }
    jetpackConfig
  ]
)
