{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  serverOn = (getModuleConfig "ssh-server-manager").enable or false;
  cliRegistry = getModuleApi "cli-registry";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
  domainGui = (getModuleApi "gui-engine").domainGui pkgs config;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;
  scriptModule = import ./scripts/ssh-client-manager.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi;
  };
  scriptPath = scriptModule.sshClientManagerScript;
  sshClientTui =
    if tuiOn
    then (import ./ui/tui/default.nix { inherit config lib pkgs systemConfig scriptPath getModuleApi; sshClientCfg = cfg; }).tuiScript
    else null;

  # Variant 1: bare = CLI manager; UI only via --gui / --tui
  clientRouter = pkgs.writeShellScriptBin "ncc-ssh-client" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui) _ui=tui ;;
        gui|tui)
          echo "Use: ncc ssh client --$_a   (not bare '$_a')" >&2
          exit 2
          ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    cmd="''${1:-}"
    case "$cmd" in
      "")
        case "$_ui" in
          gui) ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui ssh'' else guiOff} ;;
          tui)
            ${if tuiOn then ''exec ${sshClientTui}/bin/ncc-ssh-client-tui'' else tuiOff}
            ;;
          *) exec ${scriptPath}/bin/ncc-ssh-client-manager-main ;;
        esac
        ;;
      list|add|edit|delete|connect)
        exec ${scriptPath}/bin/ncc-ssh-client-manager-main "$cmd" "''${@:2}"
        ;;
      help|-h|--help)
        cat <<EOF
ncc ssh client — SSH client connections (CLI)

Usage:
  ncc ssh client                 Interactive CLI manager
  ncc ssh client --gui           Domain GUI
  ncc ssh client --tui           TUI (if enabled)
  ncc ssh client list|add|edit|delete|connect …
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
      longHelp = ''
        ncc ssh client                 CLI manager
        ncc ssh client --gui|--tui
        ncc ssh client list|add|edit|delete|connect
      '';
    }
  ] ++ optional (!serverOn) {
    name = "ssh";
    domain = "ssh";
    type = "manager";
    description = "SSH client connections";
    category = "security";
    script = "${clientRouter}/bin/ncc-ssh-client";
    shortHelp = "ssh - SSH connections";
    longHelp = ''
      ncc ssh                 CLI manager
      ncc ssh --gui|--tui
      ncc ssh client …
    '';
  };
in {
  config = mkMerge [
    (cliRegistry.registerGuiDomain "ssh" {
      label = "SSH";
      description = "SSH client connections";
      enabled = cfg.enable or false;
      group = "features";
    })
    (cliRegistry.registerGuiPage "ssh" ./ui/gui)
    (mkIf (cfg.enable or false) (
      cliRegistry.registerCommandsFor "ssh-client" clientCommands
    ))
  ];
}
