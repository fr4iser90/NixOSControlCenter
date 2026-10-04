# Turn flat { NCC_FOO = "/nix/store/…"; … } into bash export lines for ncc-gui.
{ lib }:
envs:
lib.concatStringsSep "\n" (
  lib.mapAttrsToList (k: v: ''export ${k}="${v}"'') envs
)
