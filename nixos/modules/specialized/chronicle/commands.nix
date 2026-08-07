{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
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
      shortHelp = "chronicle - Chronicle";
      longHelp = ''
        Chronicle - Your Digital Work Memory

        Record, document, and analyze workflows with AI-powered insights,
        compliance features, and enterprise-grade collaboration.

        Usage: ncc chronicle <command> [options]

        Commands:
          start [--daemon] [--debug]  - Start recording session
          stop                        - Stop current recording
          capture                     - Manually capture a step
          status                      - Show recording status
          list                        - List all recordings
          cleanup                     - Remove old recordings (>30 days)
          test                        - Run system tests
          gui                         - PySide6 control window

        Examples:
          ncc chronicle start --daemon
          ncc chronicle capture
          ncc chronicle stop
          ncc chronicle gui
      '';
    }
  ];
in
{
  config = lib.mkMerge [
    (cliRegistry.registerGuiDomain "chronicle" {
      label = "Chronicle";
      description = "Record and review workflows";
      enabled = cfg.enable or true;
    })
    registrationResult
  ];
}
