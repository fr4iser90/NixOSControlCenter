{ config, lib, pkgs, systemConfig, ... }:

let
  # Import the main script
  mainScript = import ./main-script.nix { inherit config lib pkgs systemConfig; };
in
{
  nixcc = pkgs.writeScriptBin "nixcc" ''
    #!/usr/bin/env bash
    exec ${mainScript}/bin/ncc "$@"
  '';

  nixctl = pkgs.writeScriptBin "nixctl" ''
    #!/usr/bin/env bash
    exec ${mainScript}/bin/ncc "$@"
  '';

  nix-center = pkgs.writeScriptBin "nix-center" ''
    #!/usr/bin/env bash
    exec ${mainScript}/bin/ncc "$@"
  '';

  nix-control = pkgs.writeScriptBin "nix-control" ''
    #!/usr/bin/env bash
    exec ${mainScript}/bin/ncc "$@"
  '';
}
