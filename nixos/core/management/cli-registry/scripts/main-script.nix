{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, getCurrentModuleMetadata, moduleName, ... }:

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  ccLib = import ../lib { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;
  rootTui =
    if tuiOn
    then (import ../ui/tui/default.nix { inherit config lib pkgs getModuleApi; }).tuiScript
    else null;
  rootGui = (getModuleApi "gui-engine").rootGui pkgs config;

  assistantCfg = getModuleConfig "ncc-assistant";
  assistantOn = assistantCfg.enable or false;
  assistantPkg =
    if assistantOn
    then (getModuleApi "ncc-assistant").package {
      inherit pkgs getModuleApi getModuleMetadata;
      cfg = assistantCfg;
    }
    else null;

  resolvedCommands = cliRegistry.getRegisteredCommands config;
  caseBlock = lib.concatMapStringsSep "\n  " ccLib.utils.generateExecCase resolvedCommands;
  commandLongHelp = lib.concatMapStringsSep "\n  " ccLib.utils.generateLongHelpCase resolvedCommands;
  commandList = ccLib.utils.generateCommandList resolvedCommands;

  publicCommands = lib.filter (c: !(c.internal or false)) resolvedCommands;

  titleCase = name:
    let
      n = builtins.stringLength name;
    in
      if n == 0 then name
      else lib.toUpper (builtins.substring 0 1 name) + builtins.substring 1 n name;

  # Strip redundant " (GUI)" / " (TUI)" — the root shell already is the GUI.
  cleanUiLabel = s:
    let
      m = builtins.match "(.*) \\((GUI|TUI|GUI \\+ CLI)\\)" s;
    in
      if m != null then builtins.head m else s;

  # Prefer shortHelp after " - ", cleaned; else title-cased id
  domainLabel = cmd:
    let
      sh = cmd.shortHelp or "";
      parts = lib.splitString " - " sh;
      raw =
        if sh != "" && builtins.length parts >= 2
        then builtins.elemAt parts 1
        else titleCase cmd.name;
    in
      cleanUiLabel raw;

  actionLabel = cmd:
    let
      sh = cmd.shortHelp or "";
      parts = lib.splitString " - " sh;
      raw =
        if sh != "" && builtins.length parts >= 2
        then builtins.elemAt parts 1
        else (cmd.description or cmd.name);
    in
      cleanUiLabel raw;

  # GUI catalog actions = real verbs only. Never promote TUI/GUI launchers —
  # the root shell / domain page IS the desktop UI; tui stays CLI for servers.
  guiActionSkip = [ "tui" "gui" "manager" ];
  childActions = parentName:
    map (c: {
      label = actionLabel c;
      args = [ c.name ];
    }) (
      lib.filter (c:
        (c.parent or null) == parentName
        && !(lib.elem c.name guiActionSkip)
      ) publicCommands
    );

  topLevel = lib.filter (c: (c.parent or null) == null) publicCommands;

  fromCommands = map (cmd: {
    id = cmd.name;
    label = domainLabel cmd;
    description = cmd.description or "";
    enabled = true;
    actions = childActions cmd.name;
  }) topLevel;

  guiDomainAttrs = cliRegistry.guiDomains config;
  fromGuiStubs = lib.mapAttrsToList (id: g: {
    inherit id;
    label = cleanUiLabel (g.label or id);
    description = g.description or "";
    enabled = g.enabled or false;
    actions = [];
  }) guiDomainAttrs;

  # Stubs first, then commands overwrite (enabled domains always win)
  catalogById = lib.foldl' (acc: item: acc // { ${item.id} = item; }) {} (fromGuiStubs ++ fromCommands);
  guiCatalogJson = builtins.toJSON (lib.attrValues catalogById);
  guiCatalog = pkgs.writeText "ncc-gui-catalog.json" guiCatalogJson;

  launchGui =
    if guiOn then ''
    export NCC_GUI_CATALOG="$(cat ${guiCatalog})"
    ${lib.optionalString assistantOn ''
      # Embed AI with the same env as `ncc ai` (endpoint, prompts, knowledge, …)
      # shellcheck disable=SC1091
      source ${assistantPkg.envFile}
      export PYTHONPATH="${assistantPkg.appRoot}''${PYTHONPATH:+:$PYTHONPATH}"
    ''}
    exec ${rootGui}/bin/ncc-gui
  '' else guiOff;

in
  pkgs.writeScriptBin "ncc" ''
    #!/usr/bin/env bash

    function handle_interrupt() {
      ${ui.badges.error "Operation cancelled"}
      exit 0
    }
    trap handle_interrupt INT

    function show_help() {
      ${ui.text.header "NixOS Control Center"}
      ${ui.text.normal "Usage: ncc <domain> [action]"}
      ${ui.text.normal "       ncc help <command>"}
      ${ui.text.newline}
      ${ui.text.subHeader "Available commands:"}
      echo "${commandList}"
      ${ui.text.newline}
      ${ui.text.normal "Use 'ncc help <command>' for more details on a specific command."}
    }

    function show_command_help() {
      local cmd="$1"
      if [[ -z "$cmd" ]]; then
        show_help
        exit 0
      fi
      case "$cmd" in
        ${commandLongHelp}
        *)
          ${ui.badges.error "Unknown command '$cmd'"}
          ${ui.text.newline}
          show_help
          exit 1
          ;;
      esac
    }

    function run_command() {
      local cmd="$1"
      shift
      
      if [[ -z "$cmd" ]]; then
        if [[ -n "''${DISPLAY:-}''${WAYLAND_DISPLAY:-}" ]]; then
          ${launchGui}
        fi
        ${if tuiOn then ''exec ${rootTui}/bin/ncc-ncc-tui'' else tuiOff}
      fi

      if [[ "$cmd" == "gui" ]]; then
        ${launchGui}
      fi

      if [[ "$cmd" == "tui" ]]; then
        ${if tuiOn then ''exec ${rootTui}/bin/ncc-ncc-tui'' else tuiOff}
      fi
      
      if [[ "$cmd" == "help" ]]; then
        show_command_help "$1"
        exit 0
      fi
      
      local action="$1"
      
      if [[ -n "$action" ]]; then
        local full_cmd="$cmd-$action"
        shift
        
        case "$full_cmd" in
          ${caseBlock}
          *)
            set -- "$action" "$@"
            case "$cmd" in
              ${caseBlock}
              *)
                ${ui.badges.error "Unknown command '$cmd $action'"}
                ${ui.text.newline}
                show_help
                exit 1
                ;;
            esac
            ;;
        esac
      else
        case "$cmd" in
          ${caseBlock}
          *)
            ${ui.badges.error "Unknown command or domain '$cmd'"}
            ${ui.text.newline}
            show_help
            exit 1
            ;;
        esac
      fi
    }

    run_command "$@"
  ''
