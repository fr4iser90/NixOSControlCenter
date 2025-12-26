{ lib, colors }:

let
  # Import anderer UI-Komponenten
  text = import ../core/text.nix { inherit lib colors; };
  messages = import ../status/messages.nix { inherit lib colors; };
  prompts = import ./prompts.nix { inherit lib colors; };
  boxes = import ../components/boxes.nix { inherit lib colors; };
  fzf = import ./fzf.nix { inherit lib colors; };

in {
  # Basis-Template für alle Menus
  baseTemplate = {title, content, actions, navigation ? []}: let
    # Action-Keys als String für case-statement
    actionKeys = lib.concatStringsSep " " (builtins.attrNames actions);
    actionCase = lib.concatStringsSep "\n" (lib.mapAttrsToList (key: action: ''
      "${key}"|"${lib.toUpper key}")
        ${action.handler}
        ;;
    '') actions);
  in ''
    ${text.clear}
    ${content}

    ${text.newline}
    ${prompts.input "Choose action ${actionKeys}"}

    read -rsn1 KEY
    case "$KEY" in
      ${actionCase}
      *)
        ${messages.error "Unknown action: $KEY"}
        ${messages.info "Available: ${actionKeys}"}
        sleep 2
        ;;
    esac

    ${if navigation != [] then ''
      ${text.newline}
      ${messages.info "Navigation: ${lib.concatStringsSep " " navigation}"}
      ${messages.info "Press Enter to continue..."}
      read -r
    '' else ""}
  '';

  # Hauptmenü Template - GENERISCH für alle Anwendungen
  mainMenuTemplate = {title ? "Menu", items ? [], searchEnabled ? false}: let
    # Generische Menu-Anzeige
    menuContent = lib.concatStringsSep "\n" (map (item: let
      key = item.key or "?";
      name = item.name or "Unknown";
      desc = item.description or "";
    in "  [${key}] ${name}${lib.optionalString (desc != "") " - ${desc}"}") items);

  in ''
    while true; do
      clear

      # Header
      ${text.header title}

      # Menu-Items anzeigen
      echo ""
      ${menuContent}
      echo ""

      ${if searchEnabled then ''
        echo "Type to search, or press key for action:"
      '' else ''
        echo "Press key for action:"
      ''}

      # Input lesen
      read -rsn1 key

      # Items nach Key durchsuchen
      ${let
        keyActions = lib.concatStringsSep "\n" (map (item: let
          itemKey = item.key or "?";
          action = item.action or "";
        in ''
          "${itemKey}"|"${lib.toUpper itemKey}")
            ${action}
            ;;'') items);
      in ''
        case "$key" in
          ${keyActions}
          q|Q)
            exit 0
            ;;
          *)
            ${messages.error "Unknown key: $key"}
            sleep 1
            ;;
        esac
      ''}
    done
  '';

  # fzf-Interface Template
  fzfInterfaceTemplate = {title, items, multi ? true, preview ? null}: let
    content = fzf.multiSelect {
      title = title;
      items = items;
      prompt = if multi then "Select modules" else "Select module";
      preview = preview;
    };
  in ''
    ${content}
    selected="$selected"
  '';

  # Info-Box Template
  withInfoBox = {mainContent, infoContent}: let
    mainBox = boxes.mainContainer {
      title = "Module Management";
      content = mainContent;
      sidebar = {
        title = "Module Info";
        content = infoContent;
      };
    };
  in ''
    ${mainBox}
  '';

  # Status-Übersicht Template
  statusOverviewTemplate = modules: let
    # Module nach Kategorien gruppieren
    categorizedModules = let
      categories = lib.unique (map (m: m.category or "other") modules);
    in lib.genAttrs categories (cat:
      builtins.filter (m: (m.category or "other") == cat) modules
    );

    # Kategorien-Übersicht
    overviewContent = lib.concatStringsSep "\n" (lib.mapAttrsToList (catName: catModules: let
      counts = {
        active = lib.length (builtins.filter (m: m.enabled or false) catModules);
        total = lib.length catModules;
      };
    in boxes.categoryBox {
      title = catName;
      modules = catModules;
      activeCount = counts.active;
      totalCount = counts.total;
    }) categorizedModules);

    totalActive = lib.length (builtins.filter (m: m.enabled or false) modules);
    totalModules = lib.length modules;
  in ''
    ${text.header "📋 Module Status Overview"}

    ${overviewContent}

    ${text.newline}
    Total: ${toString totalModules} modules (${toString totalActive} active)
  '';

  # Navigation-Bar Template
  navigationBar = {back ? null, actions ? []}: let
    navItems = (if back != null then ["[←] Back"] else []) ++ actions;
  in ''
    ${text.newline}
    Navigation: ${lib.concatStringsSep " " navItems}
  '';
}
