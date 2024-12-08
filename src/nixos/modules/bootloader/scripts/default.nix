{ pkgs, lib, env, ... }:

let
  utils = import ../lib/utils.nix { inherit lib; };

  # Hilfsfunktion zum Ersetzen des Hostnamens
  replaceHostname = content: builtins.replaceStrings
    ["${env.hostName}Setup"]
    ["${"\${HOSTNAME}Setup"}"]
    content;
in
{
  validateInput = pkgs.writeScriptBin "validate-boot-input" (builtins.readFile ./validateInput.sh);

  renameBootEntries = pkgs.writeScriptBin "rename-boot-entries" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # Setze Umgebungsvariablen
    HOSTNAME="${env.hostName}"
    PATH="${lib.makeBinPath [pkgs.gnused]}:$PATH"

    source ${./validateInput.sh}
    ${utils.validatePermissions}

    ${replaceHostname (builtins.readFile ./renameEntries.sh)}
  '';

  listBootEntries = pkgs.writeScriptBin "list-boot-entries" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${builtins.readFile ./listEntries.sh}
  '';

  resetBootEntry = pkgs.writeScriptBin "reset-boot-entry" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    PATH="${lib.makeBinPath [pkgs.gnused]}:$PATH"

    source ${./validateInput.sh}
    ${utils.validatePermissions}

    ${builtins.readFile ./resetEntry.sh}
  '';
}
