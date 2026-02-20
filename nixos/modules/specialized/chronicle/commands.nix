{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, moduleName, ... }:

with lib;

let
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  
  # DEBUG LOGS - Will show during build (each needs unique name!)
  _1 = builtins.trace "=== CHRONICLE DEBUG START ===" null;
  _2 = builtins.trace "[CHRONICLE] commands.nix is being evaluated" null;
  _3 = builtins.trace "[CHRONICLE] moduleName = ${moduleName}" null;
  _4 = builtins.trace "[CHRONICLE] cfg.enable = ${toString (cfg.enable or false)}" null;
  _5 = builtins.trace "[CHRONICLE] cfg = ${builtins.toJSON cfg}" null;
  
  # Import chronicleLib
  chronicleLib = import ./lib/default.nix { inherit lib pkgs cfg; };
  _6 = builtins.trace "[CHRONICLE] chronicleLib imported" null;
  
  backend = if (cfg.mode or "automatic") == "automatic" then "x11" else "wayland";
  _7 = builtins.trace "[CHRONICLE] backend = ${backend}" null;
  
  recorderScript = import ./scripts/main.nix {
    inherit lib pkgs chronicleLib backend cfg;
  };
  _8 = builtins.trace "[CHRONICLE] recorderScript created: ${recorderScript}" null;
  
  registrationResult = cliRegistry.registerCommandsFor "chronicle" [
    {
      name = "chronicle";
      description = "Chronicle - Your Digital Work Memory";
      category = "specialized";
      script = "${recorderScript}/bin/chronicle";
      arguments = ["start" "stop" "capture" "status" "list" "cleanup" "test"];
      shortHelp = "chronicle <command> - Record and analyze workflows";
      longHelp = ''
        Chronicle - Your Digital Work Memory
        
        Record, document, and analyze workflows with AI-powered insights,
        compliance features, and enterprise-grade collaboration.
        
        Usage: chronicle <command> [options]
        
        Commands:
          start [--daemon] [--debug]  - Start recording session
          stop                        - Stop current recording
          capture                     - Manually capture a step
          status                      - Show recording status
          list                        - List all recordings
          cleanup                     - Remove old recordings (>30 days)
          test                        - Run system tests
        
        Examples:
          chronicle start --daemon    # Start in background
          chronicle capture           # Manual step
          chronicle stop              # Stop and export
      '';
    }
  ];
  
  _9 = builtins.trace "[CHRONICLE] registrationResult = ${builtins.toJSON registrationResult}" null;
  _10 = builtins.trace "=== CHRONICLE DEBUG END ===" null;
in
{
  config = builtins.trace "DEBUG: [CHRONICLE] cfg in commands.nix = ${builtins.toJSON cfg}" (
    builtins.trace "DEBUG: [CHRONICLE] cfg.outputDir = ${toString (cfg.outputDir or "MISSING")}" (
      lib.mkMerge [
        registrationResult
      ]
    )
  );
}
