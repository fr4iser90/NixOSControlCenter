{ config, lib, pkgs, getModuleApi, getModuleConfig, systemConfig, ... }:
let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
  userTui =
    if tuiOn
    then (import ./ui/tui/default.nix { inherit config lib pkgs getModuleApi getModuleConfig; }).tuiScript
    else null;
  domainGui = (getModuleApi "gui-engine").domainGui pkgs config;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  usersAttrs = lib.filterAttrs
    (n: v: builtins.isAttrs v && (v ? role || v ? defaultShell))
    (systemConfig.users or {});
  userNames = lib.attrNames usersAttrs;

  userList = pkgs.writeShellScriptBin "ncc-user-list" ''
    set -euo pipefail
    ${lib.concatMapStringsSep "\n" (name:
      let
        u = usersAttrs.${name};
        role = u.role or "guest";
        shell = u.defaultShell or "bash";
        auto = if u.autoLogin or false then "true" else "false";
      in ''
        echo "${name}=${role}=${shell}=${auto}"
      ''
    ) userNames}
  '';

  entry = pkgs.writeShellScriptBin "ncc-user-entry" ''
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui) _ui=tui ;;
        gui|tui) echo "Use: ncc user --$_a" >&2; exit 2 ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    case "''${1:-}" in
      "")
        case "$_ui" in
          gui) ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui user'' else guiOff} ;;
          tui)
            ${if tuiOn then ''exec ${userTui}/bin/ncc-user-tui'' else tuiOff}
            ;;
          *)
            cat <<EOF
ncc user — User manager (CLI)

Usage:
  ncc user                 Help
  ncc user --gui           Domain GUI
  ncc user --tui           TUI (if enabled)
  ncc user list            Configured users (name=role=shell=autologin)
EOF
            ;;
        esac
        ;;
      list) exec ${userList}/bin/ncc-user-list ;;
      help|-h|--help) exec "$0" ;;
      *) echo "Usage: ncc user [--gui|--tui] | ncc user list" >&2; exit 1 ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    (cliRegistry.registerGuiDomain "user" {
      label = "Users";
      description = "User accounts and roles";
      enabled = true;
    })
    (cliRegistry.registerGuiPage "user" ./ui/gui)
    (lib.mkIf (cfg.enable or true)
      (cliRegistry.registerCommandsFor "user" (
        [
          {
            name = "user";
            domain = "user";
            description = "User manager";
            category = "base";
            script = "${entry}/bin/ncc-user-entry";
            type = "manager";
            shortHelp = "user - User Manager";
            longHelp = ''
              ncc user                 CLI help
              ncc user --gui|--tui
              ncc user list
            '';
          }
          {
            name = "list";
            parent = "user";
            domain = "user";
            description = "List configured users";
            category = "base";
            script = "${userList}/bin/ncc-user-list";
            shortHelp = "list - List users";
            longHelp = "ncc user list";
          }
        ]
        ++ lib.optionals tuiOn [
          {
            name = "tui";
            parent = "user";
            domain = "user";
            description = "User TUI";
            category = "base";
            script = "${userTui}/bin/ncc-user-tui";
            type = "manager";
            shortHelp = "tui - User TUI (prefer: ncc user --tui)";
            longHelp = "ncc user --tui";
          }
        ]
      ))
    )
  ];
}
