{ config, lib, pkgs, getModuleApi ? null, moduleName ? (baseNameOf ./.), systemConfig ? null, ... }:

let
  cfg = lib.attrByPath ["core" "base" "desktop"] {} systemConfig;
  cliRegistry = getModuleApi "cli-registry";
  desktopTui = (import ./ui/tui/default.nix { inherit config lib pkgs getModuleApi systemConfig; }).tuiScript;
in
{
  config = lib.mkIf (cfg.enable or true)
    (cliRegistry.registerCommandsFor "desktop" [
      {
        name = "desktop";
        domain = "desktop";
        description = "Desktop manager TUI";
        category = "base";
        script = "${desktopTui}/bin/ncc-desktop-tui";
        arguments = [];
        type = "manager";
        shortHelp = "desktop - Desktop Manager (TUI)";
        longHelp = ''
          Desktop manager TUI placeholder.
        '';
      }
    ]);
}
