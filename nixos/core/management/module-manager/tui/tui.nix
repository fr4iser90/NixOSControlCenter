# Module Manager TUI - Uses tui-engine templates
# Clean architecture: UI templates only, no direct scripts

{ lib, pkgs, getModuleApi, ... }:

let
  # Get APIs
  tuiEngine = getModuleApi "tui-engine";
  actions = import ./actions.nix { inherit lib pkgs; };

  # Use 5-panel template from tui-engine with actions
  tui = tuiEngine.templates."5panel".createTUI
    "📦 Module Manager"
    [ "📋 List Modules" "🔍 Search/Filter" "⚙️ Settings" "❌ Quit" ]
    actions.getModuleList
    actions.getFilterPanel
    actions.getDetailsPanel
    actions.getActionsPanel;

in
  tui