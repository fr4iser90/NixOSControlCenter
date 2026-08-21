{ config, lib, pkgs, getModuleApi, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  common = import ../lib/common.nix { inherit lib getModuleApi; };

  # Konstanten
  entriesDir = "/boot/grub/custom_entries";
  entriesFile = "${entriesDir}/grub-entries.json";
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
    mkEntryPath = gen: "${entriesDir}/nixos-generation-${toString gen}.cfg";
    
    validateEntry = { generation, name, ... }:
      assert types.generation.check generation || throw types.generation.message;
      assert types.name.check name || throw types.name.message;
      true;
      
    updateEntryFile = { generation, title, sortKey }: ''
      ${pkgs.gnused}/bin/sed -i.bak \
        -e "s/^menuentry.*$/menuentry '${title}' {" \
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
            rm -f "${entriesDir}/nixos-generation-$gen.cfg"
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
    initJson = pkgs.writeScript "init-grub-entries-json" ''
      #!${pkgs.bash}/bin/bash
      if [ ! -f "${entriesFile}" ]; then
        echo '{"generations":{},"lastUpdate":""}' > "${entriesFile}"
        chmod 644 "${entriesFile}"
      fi
    '';

    listEntries = pkgs.writeScriptBin "list-grub-entries" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      ${common.validatePermissions}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.text.header "GRUB boot entries"}
      fi
      ${ui.messages.loading "Reading ${entriesDir}…"}
      found=0
      for entry in ${entriesDir}/nixos-generation-*.cfg; do
        if [ -f "$entry" ] && [ ! -h "$entry" ]; then
          found=1
          cat "$entry"
          echo ""
        fi
      done
      if [[ "$found" -eq 0 ]]; then
        ${ui.messages.warning "No nixos-generation-*.cfg entries found"}
      else
        ${ui.messages.success "GRUB entries listed"}
      fi
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc bootentry rename GEN TITLE   or   ncc bootentry reset GEN"}
      fi
    '';

    renameEntry = pkgs.writeScriptBin "rename-grub-entry" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      ${common.validatePermissions}

      if [ $# -ne 2 ]; then
        ${ui.messages.error "Usage: rename-grub-entry GENERATION TITLE"}
        exit 2
      fi

      gen="$1"
      new_name="$2"

      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.text.header "Rename GRUB entry"}
      fi
      ${ui.messages.loading "Renaming generation $gen…"}
      ${ui.tables.keyValue "Generation" "$gen"}
      ${ui.tables.keyValue "Title" "$new_name"}
      
      ${utils.updateEntryFile {
        generation = "$gen";
        title = "$new_name";
        sortKey = "nixos";
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
      ${ui.messages.success "GRUB entry $gen renamed"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc bootentry list"}
      fi
    '';
    
    resetEntry = pkgs.writeScriptBin "reset-grub-entry" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      ${common.validatePermissions}
      
      if [ $# -ne 1 ]; then
        ${ui.messages.error "Usage: reset-grub-entry GENERATION"}
        exit 2
      fi

      gen="$1"

      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.text.header "Reset GRUB entry"}
      fi
      ${ui.messages.loading "Resetting generation $gen title…"}
      ${ui.tables.keyValue "Generation" "$gen"}
      
      ${utils.updateEntryFile {
        generation = "$gen";
        title = "NixOS";
        sortKey = "nixos";
      }}
      
      ${pkgs.jq}/bin/jq --arg gen "$gen" \
         --arg time "$(date -Iseconds)" \
         'del(.generations[$gen])' "${entriesFile}" > "${entriesFile}.tmp"
      mv "${entriesFile}.tmp" "${entriesFile}"
      ${ui.messages.success "GRUB entry $gen reset"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc bootentry list"}
      fi
    '';
  };

in {
  inherit scripts utils types;
  
  activation = {
    initializeJson = ''
      ${scripts.initJson}
    '';
    
    syncEntries = ''
      for entry in ${entriesDir}/nixos-generation-*.cfg; do
        if [ -f "$entry" ] && [ ! -h "$entry" ]; then
          gen_number=$(basename "$entry" | ${pkgs.gnugrep}/bin/grep -o '[0-9]\+')
          system_path=$(${pkgs.gnugrep}/bin/grep "^linux" "$entry" | 
                       ${pkgs.gnugrep}/bin/grep -o "/nix/store/[^/]*-nixos-system-[^/]*/" || true)
          
          if [[ "$system_path" =~ -system-([^-]+)- ]]; then
            system_type="''${BASH_REMATCH[1]}"
            ${utils.updateEntryFile {
              generation = "$gen_number";
              title = "\"$system_type\"Setup";
              sortKey = "$system_type";
            }}
            
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

      ${utils.cleanupOldEntries}
    '';
  };
}
