{ config, lib, pkgs }:

let
  tuiEngine = config.core.management.tui-engine;
  rootTui = tuiEngine.domainTui.buildRootTui {
    name = "ncc";
    title = "🧭 NixOS Control Center";
    footer = "Enter domain: ncc <domain> • help: ncc help <command>";
  };
in
{
  tuiScript = rootTui;
}