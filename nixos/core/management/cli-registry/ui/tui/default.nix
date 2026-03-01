{ config, lib, pkgs }:

let
  tuiEngine = config.core.management.tui-engine;
  # Get module path (go up from ui/tui/default.nix to module root)
  modulePath = ../../..;
  
  rootTui = tuiEngine.domainTui.buildRootTui {
    name = "ncc";
    title = "🧭 NixOS Control Center";
    footer = "Enter domain: ncc <domain> • help: ncc help <command>";
    modulePath = modulePath;  # REQUIRED - no fallbacks
  };
in
{
  tuiScript = rootTui;
}