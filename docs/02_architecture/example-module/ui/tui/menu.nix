# TUI Menu-Definition
# Purpose: TUI Menu via tui-engine (Bubble Tea)
# Uses tui-engine templates for consistent UI

{ lib, pkgs, getModuleApi, cfg, ... }:

let
  tuiEngine = getModuleApi "tui-engine";
  actions = import ./actions.nix { inherit lib pkgs cfg; };
  
  # Use 5-panel template from tui-engine
  tui = tuiEngine.templates."5panel".createTUI
    "📦 Example Module"
    [ "📋 List" "🔍 Search" "⚙️ Settings" "❌ Quit" ]
    actions.getList
    actions.getSearch
    actions.getDetails
    actions.getActions;
in
  tui
