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
      group = "features";
    })
    (cliRegistry.registerGuiPage "ai" ./ui/gui)
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
              "serve-openapi" "tray" "companion" "harness"
              "watchdog" "probe" "rollback" "red-team"
              "secrets" "workspaces" "templates" "workflows" "focus" "workflow"
              "context"
              "mcp-install"
              "maintenance"
              "permissions"
              "chain"
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
                ncc ai agent run --goal "..." --grant repo=pr --grant system=none
                ncc ai agent run --goal "..." --confirm always|writes|never
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
                ncc ai companion
                ncc ai harness status|probe NAME
                ncc ai agent run --harness qwen|dsh|native --goal "…"
                ncc ai secrets list|set|delete
                ncc ai workspaces list|add|delete
                ncc ai templates list|show|instantiate|run|instances
                ncc ai workflows show|refresh|tasks|roadmap
                ncc ai focus status|tick|snooze
                ncc ai context show|compact [--session ID] [--json]
                ncc ai workflow audit|lifecycle|fleet|plan|status|next|resume|task-start|task-finish|branch|validate|commit|pr|merge|bump
                ncc ai mcp-install NAME
                ncc ai maintenance run [--json]
                ncc ai permissions show [--grant repo=pr] [--json]
                ncc ai chain release --schedule ID [--json]
                ncc ai serve-openapi
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
        # Payload travels with the package that provides it, never with the page: an enabled
        # assistant always stages its Python, a disabled one ships none and ui/gui/page.py
        # falls back to its stub instead of importing from a source tree that isn't there.
        (cliRegistry.registerGuiPython "ai" {
          root = pkg.guiPythonRoot;
          env = pkg.guiEnv;
          fingerprint = pkg.guiFingerprint;
        })
        {
          environment.systemPackages = pkg.packages;
        }
      ]
    ))
  ];
}
