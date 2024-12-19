{ config, lib, pkgs, systemConfig, ... }:

with lib;

{
  config = {
    # Konsolen-Einstellungen
    console = {
      keyMap = systemConfig.keyboardLayout;
    };

  };
}