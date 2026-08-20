# Stacks Manager TUI Helpers
# Utility functions for TUI operations

{ lib, getModuleApi, tuiActions, ... }:

let
  ui = getModuleApi "cli-formatter";

  # Menu configuration from menu.nix
  menuConfig = import ./menu.nix;

  formatMenuItems = items: lib.concatStringsSep "\n" (
    map (item: "${item.key}) ${item.name} - ${item.description}") items
  );

  getItemsByCategory = category: lib.filter (item: item.category or "other" == category) menuConfig.items;

  createCategorizedMenu = ''
    ${ui.text.header menuConfig.title}
    ${if menuConfig.subtitle or "" != "" then ui.text.subHeader menuConfig.subtitle else ""}

    ${lib.concatStringsSep "\n\n" (
      lib.mapAttrsToList (catKey: catName:
        let
          items = getItemsByCategory catKey;
        in
        if items != [] then ''
          ${ui.text.section catName}
          ${lib.concatStringsSep "\n" (
            map (item: "  ${ui.badges.info item.key}) ${item.name}") items
          )}
        '' else ""
      ) menuConfig.categories
    )}

    ${ui.text.paragraph ''
      Use ↑↓/jk to navigate, Enter to select, / to search
      Or press the shortcut key shown in brackets
    ''}
  '';

  checkDependencies = ''
    # Check if fzf is available
    if ! command -v fzf >/dev/null 2>&1; then
      ${ui.badges.error "fzf is required for TUI mode"}
      ${ui.messages.info "Install with: nix-env -iA nixos.fzf"}
      exit 1
    fi

    # Check if ncc CLI commands are available
    if ! command -v ncc >/dev/null 2>&1; then
      ${ui.badges.error "ncc command not found"}
      exit 1
    fi
  '';

  handleUserInput = selectedItem: ''
    case "$selectedItem" in
      ${lib.concatStringsSep "\n      " (
        map (item: ''
        "${item.key}) ${item.name}")
          ${ui.messages.info "Selected: ${item.name}"}
          exec ${tuiActions}/bin/homelab-tui-actions "${item.action}" "$@"
          ;;
        "${item.name}")
          ${ui.messages.info "Selected: ${item.name}"}
          exec ${tuiActions}/bin/homelab-tui-actions "${item.action}" "$@"
          ;;'') menuConfig.items
      )}
      *)
        ${ui.badges.error "Unknown selection: $selectedItem"}
        exit 1
        ;;
    esac
  '';

  showHelp = ''
    ${ui.text.header "Stacks Manager Help"}
    cat << 'EOF'
    ${menuConfig.help}
    EOF
    ${ui.text.paragraph "Press Enter to continue"}
    read -r
  '';

  createMainLoop = ''
    while true; do
      clear
      ${createCategorizedMenu}

      ${ui.text.newline}
      printf "Choice: "
      read -r choice

      case "$choice" in
        "q"|"Q"|"quit"|"exit")
          ${ui.messages.info "Goodbye!"}
          exit 0
          ;;
        "h"|"H"|"help")
          ${showHelp}
          ;;
        *)
          if [ -n "$choice" ]; then
            ${handleUserInput "$choice"}
          fi
          ;;
      esac
    done
  '';
in
{
  inherit
    formatMenuItems
    getItemsByCategory
    createCategorizedMenu
    checkDependencies
    handleUserInput
    showHelp
    createMainLoop;
}
