{ config, lib, pkgs, getModuleApi ? null, moduleName ? (baseNameOf ./.), systemConfig ? null, ... }:

let
  cfg = lib.attrByPath ["core" "base" "network"] {} systemConfig;
  cliRegistry = getModuleApi "cli-registry";
  networkTui = (import ./ui/tui/default.nix { inherit config lib pkgs getModuleApi systemConfig; }).tuiScript;
in
{
  config = lib.mkIf (cfg.enable or true)
    (cliRegistry.registerCommandsFor "network" [
      {
        name = "network";
        domain = "network";
        description = "Network manager TUI";
        category = "base";
        script = "${networkTui}/bin/ncc-network-tui";
        arguments = [];
        type = "manager";
        shortHelp = "network - Network Manager (TUI)";
        longHelp = ''
          Network manager TUI placeholder.
        '';
      }
    ]);
}
