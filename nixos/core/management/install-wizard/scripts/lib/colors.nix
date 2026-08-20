# SSOT colors from cli-formatter (no private ANSI palette).
{ pkgs, getModuleApi ? null, ... }:
assert getModuleApi != null;
let
  ui = getModuleApi "cli-formatter";
  c = ui.colors;
in
pkgs.writeText "colors.sh" ''
#!/usr/bin/env bash
# Generated from getModuleApi "cli-formatter" — do not edit palette here.
export RED='${c.red}'
export GREEN='${c.green}'
export YELLOW='${c.yellow}'
export BLUE='${c.blue}'
export PURPLE='${c.magenta}'
export CYAN='${c.cyan}'
export GRAY='${c.dim}'
export BOLD='${c.bold}'
export NC='${c.reset}'
export COLORS_IMPORTED=1
''
