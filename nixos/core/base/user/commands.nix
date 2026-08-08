{ config, lib, pkgs, getModuleApi, getModuleConfig, getModuleMetadata, systemConfig, ... }:
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

  userCli = import ./scripts/ncc-user.nix { inherit pkgs getModuleMetadata; };

  wrap = name: args: pkgs.writeShellScriptBin name ''
    exec ${userCli}/bin/ncc-user ${args} "$@"
  '';

  listBin = wrap "ncc-user-list" "list";
  showBin = wrap "ncc-user-show" "show";
  whoamiBin = wrap "ncc-user-whoami" "whoami";
  createBin = wrap "ncc-user-create" "create";
  setBin = wrap "ncc-user-set" "set";
  deleteBin = wrap "ncc-user-delete" "delete";

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
          *) exec ${userCli}/bin/ncc-user --help ;;
        esac
        ;;
      help|-h|--help) exec ${userCli}/bin/ncc-user --help ;;
      *) exec ${userCli}/bin/ncc-user "$@" ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    (cliRegistry.registerGuiDomain "user" {
      label = "Users";
      description = "User accounts and roles";
      enabled = true;
      group = "core";
    })
    (cliRegistry.registerGuiPage "user" ./ui/gui)
    (lib.mkIf (cfg.enable or true)
      (cliRegistry.registerCommandsFor "user" (
        [
          {
            name = "user";
            domain = "user";
            description = "Users";
            category = "base";
            script = "${entry}/bin/ncc-user-entry";
            type = "manager";
            shortHelp = "user - Users";
            longHelp = ''
              ncc user                 CLI help
              ncc user --gui|--tui
              ncc user list [--json]
              ncc user show NAME
              ncc user whoami
              ncc user create NAME --role ROLE …
              ncc user set NAME [--role ROLE] …
              ncc user delete NAME
            '';
          }
          {
            name = "list";
            parent = "user";
            domain = "user";
            description = "List configured users";
            category = "base";
            script = "${listBin}/bin/ncc-user-list";
            shortHelp = "list - List users";
            longHelp = "ncc user list [--json]";
          }
          {
            name = "show";
            parent = "user";
            domain = "user";
            description = "Show one user";
            category = "base";
            script = "${showBin}/bin/ncc-user-show";
            shortHelp = "show - User details";
            longHelp = "ncc user show NAME [--json]";
          }
          {
            name = "whoami";
            parent = "user";
            domain = "user";
            description = "Current user and role";
            category = "base";
            script = "${whoamiBin}/bin/ncc-user-whoami";
            shortHelp = "whoami - Current role";
            longHelp = "ncc user whoami [--json]";
          }
          {
            name = "create";
            parent = "user";
            domain = "user";
            description = "Create user account";
            category = "base";
            script = "${createBin}/bin/ncc-user-create";
            permission = "user.create";
            shortHelp = "create - Create user";
            longHelp = "ncc user create NAME --role ROLE [--shell SHELL] [--auto-login true|false] [--rebuild]";
          }
          {
            name = "set";
            parent = "user";
            domain = "user";
            description = "Update user account";
            category = "base";
            script = "${setBin}/bin/ncc-user-set";
            permission = "user.set";
            shortHelp = "set - Update user";
            longHelp = "ncc user set NAME [--role ROLE] [--shell SHELL] [--auto-login true|false] [--rebuild]";
          }
          {
            name = "delete";
            parent = "user";
            domain = "user";
            description = "Delete user account";
            category = "base";
            script = "${deleteBin}/bin/ncc-user-delete";
            permission = "user.delete";
            shortHelp = "delete - Delete user";
            longHelp = "ncc user delete NAME [--rebuild]";
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
