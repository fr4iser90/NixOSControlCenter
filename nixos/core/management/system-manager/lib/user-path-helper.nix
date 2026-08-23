# Resolve system-manager.localSourceDir to a nixos tree path (or "" when unset).
{ lib, getModuleConfig }:
let
  configured = lib.strings.trim (getModuleConfig "system-manager").localSourceDir or "";
in
  if configured == "" then
    ""
  else if builtins.pathExists "${configured}/flake.nix"
    && builtins.pathExists "${configured}/core/management" then
    configured
  else if builtins.pathExists "${configured}/nixos/flake.nix"
    && builtins.pathExists "${configured}/nixos/core/management" then
    "${configured}/nixos"
  else
    configured
