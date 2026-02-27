{ config, lib, pkgs, getModuleApi ? null, moduleName ? (baseNameOf ./.), systemConfig ? null, ... }:
let
  cfg = lib.attrByPath ["core" "base" "user"] {} systemConfig;
  cliRegistry = getModuleApi "cli-registry";
  userTui = (import ./ui/tui/default.nix { inherit config lib pkgs getModuleApi systemConfig; }).tuiScript;
in
{
  config = lib.mkIf (cfg.enable or true)
    (cliRegistry.registerCommandsFor "user" [
      {
        name = "user";
        domain = "user";
        description = "User manager TUI";
        category = "base";
        script = "${userTui}/bin/ncc-user-tui";
        arguments = [];
        type = "manager";
        shortHelp = "user - User Manager (TUI)";
        longHelp = ''
          User manager TUI placeholder.
        '';
      }
    ]);
}
