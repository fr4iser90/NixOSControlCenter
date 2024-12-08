{ pkgs, lib, env, currentSetup, ... }:

let
  utils = import ../lib/utils.nix { inherit lib; };
  entryManager = import ../lib/entries/manager.nix { inherit lib pkgs; };
in
{
  validateInput = pkgs.writeScriptBin "validate-boot-input" (builtins.readFile ./validateInput.sh);

  renameBootEntries = pkgs.writeScriptBin "rename-boot-entries" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # Setze Umgebungsvariablen
    SETUP_NAME="${currentSetup.name}"
    SORT_KEY="${currentSetup.sortKey}"
    SETUP_LIMIT=${toString currentSetup.limit}
    ENTRIES_FILE="${entryManager.dataPath}"
    PATH="${lib.makeBinPath [pkgs.gnused pkgs.jq]}:$PATH"

    # Initialisiere Entries-Datei
    ${entryManager.initScript}

    # Lade Hilfsfunktionen
    ${entryManager.updateEntry}

    source ${./validateInput.sh}
    ${utils.validatePermissions}

    ${builtins.readFile ./renameEntries.sh}
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

  manageEntries = pkgs.writeScriptBin "manage-entries" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ENTRIES_FILE="${entryManager.entriesFile}"
    PATH="${lib.makeBinPath [pkgs.jq]}:$PATH"

    ${builtins.readFile ./manageEntries.sh}
  '';
}
