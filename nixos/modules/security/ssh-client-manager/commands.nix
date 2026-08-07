{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  serverOn = (getModuleConfig "ssh-server-manager").enable or false;
  cliRegistry = getModuleApi "cli-registry";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
  domainGui = (getModuleApi "gui-engine").domainGui pkgs;
  scriptModule = import ./scripts/ssh-client-manager.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi;
  };
  scriptPath = scriptModule.sshClientManagerScript;
  sshClientTui =
    if tuiOn
    then (import ./ui/tui/default.nix { inherit config lib pkgs systemConfig scriptPath getModuleApi; sshClientCfg = cfg; }).tuiScript
    else null;

  clientRouter = pkgs.writeShellScriptBin "ncc-ssh-client" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    cmd="''${1:-}"
    case "$cmd" in
      ""|gui)
        exec ${domainGui}/bin/ncc-domain-gui ssh
        ;;
      tui)
        ${if tuiOn then ''exec ${sshClientTui}/bin/ncc-ssh-client-tui'' else tuiOff}
        ;;
      list|add|edit|delete|connect)
        exec ${scriptPath}/bin/ncc-ssh-client-manager-main "$cmd" "''${@:2}"
        ;;
      help|-h|--help)
        cat <<EOF
ncc ssh client — SSH client connections

Usage:
  ncc ssh client                 GUI
  ncc ssh client tui             TUI (if enabled)
  ncc ssh client list|add|edit|delete|connect
EOF
        ;;
      *)
        echo "Unknown: ncc ssh client $cmd" >&2
        exit 1
        ;;
    esac
  '';

  clientCommands = [
    {
      name = "client";
      parent = "ssh";
      domain = "ssh";
      type = "manager";
      description = "SSH client connections";
      category = "security";
      script = "${clientRouter}/bin/ncc-ssh-client";
      shortHelp = "client - SSH client connections";
      longHelp = "ncc ssh client list|add|edit|delete|connect";
    }
  ] ++ optional (!serverOn) {
    # Client-only: provide top-level `ncc ssh` (server-manager owns it when enabled).
    name = "ssh";
    domain = "ssh";
    type = "manager";
    description = "SSH client connections";
    category = "security";
    script = "${clientRouter}/bin/ncc-ssh-client";
    shortHelp = "ssh - SSH connections";
    longHelp = ''
      ncc ssh                 GUI
      ncc ssh client …
    '';
  };
in {
  config = mkMerge [
    (cliRegistry.registerGuiDomain "ssh" {
      label = "SSH";
      description = "SSH client connections";
      enabled = cfg.enable or false;
    })
    (mkIf (cfg.enable or false) (
      cliRegistry.registerCommandsFor "ssh-client" clientCommands
    ))
  ];
}
