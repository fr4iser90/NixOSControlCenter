{ lib, pkgs, ... }:

let
  # Speicherort im Boot-Verzeichnis
  dataDir = "/boot/loader/entries";
  dataPath = "${dataDir}/bootloader-entries.json";

  # Initialer Inhalt
  initialData = {
    generations = {};
    lastUpdate = "";
  };

  # Script zum Initialisieren der Datei
  initScript = pkgs.writeScript "init-entries" ''
    #!${pkgs.bash}/bin/bash
    if [ ! -f ${dataPath} ]; then
      echo '${builtins.toJSON initialData}' > ${dataPath}
      chmod 644 ${dataPath}
    fi
  '';
in {
  inherit dataPath initScript;

  # Hilfsfunktionen für Scripts
  getEntry = generation: ''
    if [ -f "${dataPath}" ]; then
      jq -r --arg gen "${toString generation}" '.generations[$gen] // empty' "${dataPath}"
    fi
  '';

  updateEntry = ''
    update_entries_file() {
      local gen_number=$1
      local title=$2
      local sort_key=$3

      if [ ! -f "${dataPath}" ]; then
        echo '${builtins.toJSON initialData}' > "${dataPath}"
      fi

      local json_entry=$(jq --arg gen "$gen_number" \
                           --arg title "$title" \
                           --arg sort "$sort_key" \
                           --arg time "$(date -Iseconds)" \
                           '.generations[$gen] = {
                             "title": $title,
                             "sortKey": $sort,
                             "lastUpdate": $time
                           }' "${dataPath}")

      echo "$json_entry" > "${dataPath}"
    }
  '';
}
