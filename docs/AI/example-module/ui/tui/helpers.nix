# TUI-spezifische Utilities
# Purpose: Helper-Funktionen für TUI

{ lib, pkgs, ... }:

{
  # Format data for TUI display
  formatForTUI = data:
    lib.concatMapStringsSep "\n" (item: 
      "${item.name}: ${item.value}"
    ) data;
  
  # Parse TUI input
  parseTUIInput = input:
    lib.splitString " " input;
}
