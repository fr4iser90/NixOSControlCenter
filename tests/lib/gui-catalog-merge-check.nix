# Regression: stub enabled=false + alwaysVisible=false must survive command merge.
{ lib ? import <nixpkgs/lib> }:
let
  merge = import ../../nixos/core/management/cli-registry/lib/merge-gui-catalog.nix {
    inherit lib;
  };
  stub = {
    id = "hyprland";
    label = "Hyprland";
    description = "rices";
    enabled = false;
    group = "core";
    alwaysVisible = false;
    actions = [ ];
  };
  cmd = {
    id = "hyprland";
    label = "hyprland - help";
    description = "cli";
    enabled = true;
    actions = [
      {
        label = "status";
        args = [ "status" ];
      }
    ];
  };
  out = merge [
    stub
    cmd
  ];
  h = out.hyprland;
in
assert h.enabled == false;
assert h.alwaysVisible == false;
assert h.group == "core";
assert h.label == "Hyprland";
assert (builtins.length h.actions) == 1;
true
