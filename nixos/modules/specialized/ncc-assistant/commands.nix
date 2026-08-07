{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
in
{
  config = mkMerge [
    (cliRegistry.registerGuiDomain "ai" {
      label = "AI Assistant";
      description = "Chat, agent, and tools";
      enabled = cfg.enable or false;
    })
    (mkIf (cfg.enable or false) (
      let
        pkg = import ./package.nix { inherit pkgs lib cfg getModuleApi getModuleMetadata; };
        registrationResult = cliRegistry.registerCommandsFor "ncc-assistant" [
          {
            name = "ai";
            domain = "ai";
            type = "manager";
            description = "NCC AI Assistant - chat, agent, MCP tools";
            category = "specialized";
            script = "${pkg.nccAssistant}/bin/ncc-assistant";
            arguments = [
              "gui" "chat" "cli" "mcp"
              "tool" "tools"
              "agent" "jobs"
              "playbook" "presence"
              "approve" "knowledge"
              "export" "eval"
              "serve-openapi" "tray"
              "watchdog" "probe" "rollback" "red-team"
            ];
            shortHelp = "ai - AI Assistant";
            longHelp = ''
              NCC AI Assistant

              Usage:
                ncc ai              Graphical window (default)
                ncc ai gui          Graphical window
                ncc ai chat         Terminal chat
                ncc ai cli          Terminal chat alias
                ncc ai mcp          MCP stdio server

              Agent:
                ncc ai agent run --goal "..."
                ncc ai jobs list
                ncc ai playbook list|run NAME

              Tools:
                ncc ai tools
                ncc ai tool NAME

              Other:
                ncc ai presence status|pause|resume
                ncc ai approve list|allow|block
                ncc ai knowledge sync
                ncc ai export session|job|latest
                ncc ai eval run
                ncc ai tray
                ncc ai watchdog list|fire EVENT
                ncc ai probe disk
                ncc ai rollback
                ncc ai red-team

              Config in systemConfig; auth cached under ~/.config/ncc-assistant/.
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
    ))
  ];
}
