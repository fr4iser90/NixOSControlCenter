{ config, lib, pkgs, ... }:

with lib;

let
  # Konstanten
  entriesDir = "/boot/loader/entries";
  entriesFile = "${entriesDir}/bootloader-entries.json";
  maxEntriesPerType = 5;  # Limit pro Sort-Key

  # Basis-Typen und Validierung
  types = {
    generation = {
      check = x: isInt x && x > 0 && x < 1000;
      message = "Generation must be between 1 and 999";
    };
    
    name = {
      check = x: isString x && builtins.match "[a-zA-Z0-9_\\-]+" x != null;
      message = "Name must contain only alphanumeric, underscore, and dash";
    };
  };

  # Hilfsfunktionen
  utils = {
    mkEntryPath = gen: "${entriesDir}/nixos-generation-${toString gen}.conf";
    
    validateEntry = { generation, name, ... }:
      assert types.generation.check generation || throw types.generation.message;
      assert types.name.check name || throw types.name.message;
      true;
      
    updateEntryFile = { generation, title, sortKey ? "nixos" }: ''
      ${pkgs.gnused}/bin/sed -i.bak \
        -e "s/^title.*$/title ${title}/" \
        -e "s/^sort-key.*$/sort-key ${sortKey}/" \
        "${utils.mkEntryPath generation}"
    '';

    cleanupOldEntries = ''
      if [ -f "${entriesFile}" ]; then
        # Gruppiere nach Sort-Key und behalte nur die neuesten Einträge
        ${pkgs.jq}/bin/jq -r --argjson max ${toString maxEntriesPerType} '
          .generations
          | to_entries
          | group_by(.value.sortKey)
          | .[]
          | sort_by(.key | tonumber)
          | reverse
          | .[$max:]
          | .[].key
        ' "${entriesFile}" | while read -r gen; do
          if [ ! -z "$gen" ]; then
            rm -f "${entriesDir}/nixos-generation-$gen.conf"
            ${pkgs.jq}/bin/jq --arg gen "$gen" \
              'del(.generations[$gen])' "${entriesFile}" > "${entriesFile}.tmp" \
              && mv "${entriesFile}.tmp" "${entriesFile}"
          fi
        done
      fi
    '';
  };

  # Core-Funktionen als Shell-Scripts
  scripts = {
    initJson = pkgs.writeScript "init-entries-json" ''
      #!${pkgs.bash}/bin/bash
      if [ ! -f "${entriesFile}" ]; then
        echo '{"generations":{},"lastUpdate":""}' > "${entriesFile}"
        chmod 644 "${entriesFile}"
      fi
    '';

    listEntries = pkgs.writeScriptBin "list-boot-entries" ''
      #!${pkgs.bash}/bin/bash
      for entry in ${entriesDir}/nixos-generation-*.conf; do
        if [ -f "$entry" ] && [ ! -h "$entry" ]; then
          gen_number=$(basename "$entry" | ${pkgs.gnugrep}/bin/grep -o '[0-9]\+')
          cat "$entry"
        fi
      done
    '';

    renameEntry = pkgs.writeScriptBin "rename-boot-entry" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      
      gen="$1"
      new_name="$2"
      
      ${utils.updateEntryFile {
        generation = "$gen";
        title = "$new_name";
      }}
      
      if [ -f "${entriesFile}" ]; then
        ${pkgs.jq}/bin/jq --arg gen "$gen" \
           --arg title "$new_name" \
           --arg time "$(date -Iseconds)" \
           '.generations[$gen] = {
             "title": $title,
             "lastUpdate": $time
           }' "${entriesFile}" > "${entriesFile}.tmp" \
           && mv "${entriesFile}.tmp" "${entriesFile}"
      fi
    '';
    
    resetEntry = pkgs.writeScriptBin "reset-boot-entry" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      
      if [ $# -ne 1 ]; then
        exit 1
      fi

      gen="$1"
      
      ${utils.updateEntryFile {
        generation = "$gen";
        title = "NixOS";
        sortKey = "nixos";
      }}
      
      ${pkgs.jq}/bin/jq --arg gen "$gen" \
         --arg time "$(date -Iseconds)" \
         'del(.generations[$gen])' "${entriesFile}" > "${entriesFile}.tmp"
      mv "${entriesFile}.tmp" "${entriesFile}"
    '';
  };

in {
  inherit scripts utils types;
  
  activation = {
    initializeJson = ''
      ${scripts.initJson}
    '';
    
    syncEntries = ''
      for entry in ${entriesDir}/nixos-generation-*.conf; do
        if [ -f "$entry" ] && [ ! -h "$entry" ]; then
          gen_number=$(basename "$entry" | ${pkgs.gnugrep}/bin/grep -o '[0-9]\+')
          system_path=$(${pkgs.gnugrep}/bin/grep "^options" "$entry" | 
                       ${pkgs.gnugrep}/bin/grep -o "/nix/store/[^/]*-nixos-system-[^/]*/")
          
          if [[ "$system_path" =~ -system-([^-]+)- ]]; then
            system_type="''${BASH_REMATCH[1]}"
            ${utils.updateEntryFile {
              generation = "$gen_number";
              title = "\"$system_type\"Setup";
              sortKey = "$system_type";
            }}
            
            # Update JSON
            if [ -f "${entriesFile}" ]; then
              ${pkgs.jq}/bin/jq --arg gen "$gen_number" \
                 --arg title "\"$system_type\"Setup" \
                 --arg sort "$system_type" \
                 --arg time "$(date -Iseconds)" \
                 '.generations[$gen] = {
                   "title": $title,
                   "sortKey": $sort,
                   "lastUpdate": $time
                 }' "${entriesFile}" > "${entriesFile}.tmp" \
                 && mv "${entriesFile}.tmp" "${entriesFile}"
            fi
          fi
        fi
      done

      # Cleanup alte Einträge
      ${utils.cleanupOldEntries}
    '';
  };
}