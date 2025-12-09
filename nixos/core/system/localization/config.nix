{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.system.localization or {};
  # CRITICAL: Use absolute path to deployed location, not relative (which resolves to store)
  userConfigFile = "/etc/nixos/core/system/localization/localization-config.nix";
  symlinkPath = "/etc/nixos/configs/localization-config.nix";
  configHelpers = config.core.management.system-manager.api.configHelpers;
  defaultConfig = ''
{
  localization = {
    locales = [ "en_US.UTF-8" ];
    keyboardLayout = "us";
    keyboardOptions = "";
  };
}
'';
  
  locales = cfg.locales or [ "en_US.UTF-8" ];
  defaultLocale = if builtins.length locales > 0 then builtins.head locales else "en_US.UTF-8";
  keyboardLayout = cfg.keyboardLayout or "us";
  keyboardOptions = cfg.keyboardOptions or "";
  
  # Extract language code from locale (e.g., "de_DE.UTF-8" -> "de_DE")
  # Format: "LANGUAGE_COUNTRY.ENCODING" -> "LANGUAGE_COUNTRY"
  extractLanguageCode = loc:
    let
      # Remove encoding part (everything after last dot)
      withoutEncoding = lib.head (lib.splitString "." loc);
      # Split by underscore to get language and country
      parts = lib.splitString "_" withoutEncoding;
      language = if builtins.length parts >= 1 then lib.head parts else "en";
      country = if builtins.length parts >= 2 then lib.elemAt parts 1 else (lib.toUpper language);
    in
      "${language}_${country}";
  
  localeToExtraSettings = loc: {
    LC_TIME = loc;
    LC_MONETARY = loc;
    LC_PAPER = loc;
    LC_NAME = loc;
    LC_ADDRESS = loc;
    LC_TELEPHONE = loc;
    LC_MEASUREMENT = loc;
    # Automatically extract language code from locale (e.g., "de_DE.UTF-8" -> "de_DE:en_US")
    LANGUAGE = let langCode = extractLanguageCode loc; in "${langCode}:en_US";
  };
  
  extraSettings = localeToExtraSettings defaultLocale;
in
{
  config = lib.mkMerge [
    {
      # Create symlink on activation (always)
      system.activationScripts.localization-config-symlink =
        configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig;
    }
    {
      # Localization configuration (always active, no enable check needed)
      i18n = {
        defaultLocale = defaultLocale;
        extraLocaleSettings = extraSettings;
        # Use extraLocales instead of deprecated supportedLocales
        # Include all locales from config, but remove the defaultLocale to avoid duplicates
        extraLocales = lib.filter (loc: loc != defaultLocale) locales;
      };
      console.keyMap = if keyboardLayout != "" && keyboardLayout != "(unset)" 
                      then keyboardLayout 
                      else "us";
      services.xserver = {
        xkb = {
          layout = keyboardLayout;
          options = keyboardOptions;
        };
      };
    }
  ];
}

