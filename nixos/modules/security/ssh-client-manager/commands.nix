{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
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
        ${if tuiOn then ''exec ${sshClientTui}/bin/ncc-ssh-client-tui'' else ''
          echo "ncc ssh client — use: list|add|edit|delete|connect" >&2
          echo "(TUI disabled; set tui-engine.enable = true in systemConfig for interactive UI)" >&2
          exit 1
        ''}
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
  ncc ssh client                 TUI (if enabled)
  ncc ssh client list|add|edit|delete|connect
EOF
        ;;
      *)
        echo "Unknown: ncc ssh client $cmd" >&2
        exit 1
        ;;
    esac
  '';
in {
  config = mkIf (cfg.enable or false) (
    cliRegistry.registerCommandsFor "ssh-client" [
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
    ]
  );
}
