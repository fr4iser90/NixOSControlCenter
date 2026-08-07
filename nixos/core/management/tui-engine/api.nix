# TUI Engine API — behavior only. Identity/fromConfig injected by getModuleApi.
{ lib, metadata, getModuleMetadata }:

{
  disabledHint = import ./lib/disabled-hint.nix;

  isEnabled = getModuleConfig:
    let
      tui = getModuleConfig "tui-engine";
      desktop = getModuleConfig "desktop";
      raw = tui.enable or null;
      desktopEnable = desktop.enable or null;
    in
      if raw != null then raw
      else if desktopEnable == null then false
      else !desktopEnable;
}
