{ config, lib, pkgs, colors, formatting, reportLevels, currentLevel, ... }:

with lib;

let
  entriesDir = "/boot/loader/entries";
  
  # Hilfsfunktionen
  getBootEntries = ''
    if [ -d "${entriesDir}" ]; then
      entries=$(ls ${entriesDir}/nixos-generation-*.conf 2>/dev/null || true)
      if [ ! -z "$entries" ]; then
        for entry in $entries; do
          gen=$(basename "$entry" | grep -o '[0-9]\+')
          title=$(grep "^title" "$entry" 2>/dev/null | cut -d' ' -f2-)
          version=$(grep "^version" "$entry" 2>/dev/null | cut -d' ' -f2-)
          echo "  Generation $gen:"
          echo "    Title: $title"
          echo "    Version: $version"
          echo ""
        done
      else
        echo "  No boot entries found"
      fi
    else
      echo "  Boot entries directory not found"
    fi
  '';

  minimalReport = ''
    printf '%b' "${colors.cyan}=== Boot Entries ===${colors.reset}\n"
    echo "Boot Directory: ${entriesDir}"
  '';

  standardReport = ''
    ${minimalReport}
    echo -e "\nCurrent Entries:"
    ${getBootEntries}
  '';

  detailedReport = standardReport;

  fullReport = ''
    ${standardReport}
    echo -e "\nBoot Entry Details:"
    if [ -d "${entriesDir}" ]; then
      for entry in ${entriesDir}/nixos-generation-*.conf; do
        if [ -f "$entry" ]; then
          echo -e "\nEntry: $(basename "$entry")"
          echo "Contents:"
          echo "$(cat "$entry" | ${pkgs.gnused}/bin/sed 's/^/  /')"
        fi
      done
    fi
  '';

in {
  collect = 
    if currentLevel >= reportLevels.full then fullReport
    else if currentLevel >= reportLevels.detailed then detailedReport
    else if currentLevel >= reportLevels.standard then standardReport
    else minimalReport;
}