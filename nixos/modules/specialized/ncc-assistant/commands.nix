{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, moduleName, ... }:

with lib;

let
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
in
{
  config = mkIf (cfg.enable or false) (
    let
      pkg = import ./package.nix { inherit pkgs lib cfg; };
      registrationResult = cliRegistry.registerCommandsFor "ncc-assistant" [
        {
          name = "ai";
          domain = "specialized";
          type = "manager";
          description = "NCC AI Assistant — graphical chat + MCP tools";
          category = "specialized";
          script = "${pkg.nccAssistant}/bin/ncc-assistant";
          arguments = [ "gui" "chat" "cli" "mcp" "tool" "tools" ];
          shortHelp = "ai - Open NCC AI chat window (GUI)";
          longHelp = ''
            NCC AI Assistant

            Usage:
              ncc ai              Graphical chat window (default)
              ncc ai gui          Graphical chat window
              ncc ai chat         Terminal chat (legacy)
              ncc ai cli          Terminal chat alias
              ncc ai mcp          MCP stdio server (Cursor / Claude Code)
              ncc ai tools        List tools
              ncc ai tool NAME --args '{...}'

            Config: endpoint (+ optional model/maxTokens). Auth is prompted
            in the GUI and cached under ~/.config/ncc-assistant/.
          '';
        }
      ];
    in
    mkMerge [
      registrationResult
      {
        environment.systemPackages = pkg.packages;
      }
    ]
  );
}
