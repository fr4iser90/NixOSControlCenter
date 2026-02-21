# fzf-spezifische Utilities
# Purpose: Helper-Funktionen für fzf-Menus

{ lib, pkgs, ... }:

{
  # Format menu items for fzf
  formatMenuItems = items:
    lib.concatMapStringsSep "\n" (item: 
      "${item.name}|${item.action}|${item.description or ""}"
    ) items;
  
  # Parse fzf selection
  parseSelection = selection:
    let
      parts = lib.splitString "|" selection;
    in
      if lib.length parts >= 2 then
        { name = lib.elemAt parts 0; action = lib.elemAt parts 1; }
      else
        null;
}
