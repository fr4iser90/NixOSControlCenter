{ config, lib, pkgs, getModuleApi }:

let
  tuiEngine = (getModuleApi "tui-engine").fromConfig config;
  modulePath = ../../..;

  rootTui = tuiEngine.domainTui.buildRootTui {
    name = "ncc";
    title = "🧭 NixOS Control Center";
    footer = "Enter domain: ncc <domain> • help: ncc help <command>";
    layout = null;
    inherit modulePath;
  };
in
{
  tuiScript = rootTui;
}
