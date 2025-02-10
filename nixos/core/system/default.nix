{ config, lib, pkgs, systemConfig, ... }:

with lib;

{
  config = {
    # Locale-Einstellungen
    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocaleSettings = {
        LC_TIME = "de_DE.UTF-8";
        LC_MONETARY = "de_DE.UTF-8";
        LC_PAPER = "de_DE.UTF-8";
        LC_NAME = "de_DE.UTF-8";
        LC_ADDRESS = "de_DE.UTF-8";
        LC_TELEPHONE = "de_DE.UTF-8";
        LC_MEASUREMENT = "de_DE.UTF-8";
        LANGUAGE = "de_DE:en_US";
      };
      supportedLocales = [
        "en_US.UTF-8/UTF-8"
        "de_DE.UTF-8/UTF-8"
      ];
    };

    # Konsolen-Einstellungen (jetzt unter console statt i18n.console)
    console.keyMap = if systemConfig.keyboardLayout != null && systemConfig.keyboardLayout != "" then systemConfig.keyboardLayout else "us";
  };
}