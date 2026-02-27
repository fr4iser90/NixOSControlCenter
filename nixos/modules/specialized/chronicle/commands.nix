{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, moduleName, ... }:

with lib;

let
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  
  # Import chronicleLib
  chronicleLib = import ./lib/default.nix { inherit lib pkgs cfg; };
  
  backend = if (cfg.mode or "automatic") == "automatic" then "x11" else "wayland";
  
  recorderScript = import ./scripts/main.nix {
    inherit lib pkgs chronicleLib backend cfg;
  };
  
  registrationResult = cliRegistry.registerCommandsFor "chronicle" [
    {
      name = "chronicle";
      domain = "chronicle";
      type = "manager";
      description = "Chronicle - Your Digital Work Memory";
      category = "specialized";
      script = "${recorderScript}/bin/chronicle";
      arguments = ["start" "stop" "capture" "status" "list" "cleanup" "test"];
      shortHelp = "chronicle - Record and analyze workflows";
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
in
{
  config = lib.mkMerge [
    registrationResult
  ];
}
