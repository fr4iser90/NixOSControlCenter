{ config, lib, pkgs, ui, reportLevels, currentLevel, ... }:

with lib;

let
  entriesDir = "/boot/loader/entries";
  
  # Helper function to get boot entries
  getBootEntries = ''
    if [ -d "${entriesDir}" ]; then
      entries=$(ls ${entriesDir}/nixos-generation-*.conf 2>/dev/null || true)
      if [ ! -z "$entries" ]; then
        for entry in $entries; do
          gen=$(basename "$entry" | grep -o '[0-9]\+')
          title=$(grep "^title" "$entry" 2>/dev/null | cut -d' ' -f2-)
          version=$(grep "^version" "$entry" 2>/dev/null | cut -d' ' -f2-)
          ${ui.tables.keyValue "Generation $gen" ""}
          ${ui.tables.keyValue "  Title" "$title"}
          ${ui.tables.keyValue "  Version" "$version"}
          echo ""
        done
      else
        ${ui.messages.warning "No boot entries found"}
      fi
    else
      ${ui.messages.error "Boot entries directory not found"}
    fi
  '';

  # Standard report shows current boot entries
  standardReport = ''
    ${ui.text.header "Boot Entries"}
    ${ui.text.subHeader "Current Entries:"}
    ${getBootEntries}
  '';

  # Detailed shows same as standard
  detailedReport = standardReport;

  # Full report shows just standard info
  fullReport = standardReport;

in {
  collect = 
    if currentLevel >= reportLevels.full then fullReport
    else if currentLevel >= reportLevels.detailed then detailedReport
    else if currentLevel >= reportLevels.standard then standardReport
    else "";  # Minimal level: show nothing
}