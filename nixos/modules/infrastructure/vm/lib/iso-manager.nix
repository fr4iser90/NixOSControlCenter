{ lib, pkgs }:

let
  # Helper für ISO-Validierung
  validateIso = path: ''
    validate_iso() {
      local path="$1"
      echo "Debug: Checking ISO file: $path" >&2
      
      # Prüfe Datei-Existenz und Größe
      if [ ! -f "$path" ] || [ ! -s "$path" ]; then
        echo "Debug: File not found or empty: $path" >&2
        return 1
      fi
      
      # Zeige tatsächlichen Dateityp
      local file_type=$(${pkgs.file}/bin/file "$path")
      echo "Debug: File type detected: $file_type" >&2
      
      # Erweiterte Prüfung mit mehr Patterns
      if echo "$file_type" | grep -iE "ISO 9660|ISO DOS/MBR boot sector|x86 boot sector|bootable disk" > /dev/null; then
        echo "Debug: ISO validation passed for $path" >&2
        return 0
      else
        echo "Debug: ISO validation failed - unexpected file type" >&2
        return 1
      fi
    }
  '';

  # Helper für Download mit Fortschrittsanzeige
  downloadWithProgress = ''
    download_with_progress() {
      local url="$1"
      local output="$2"
      echo "  Debug: Downloading from URL: $url"  # Debug-Ausgabe
      ${pkgs.wget}/bin/wget \
        --progress=bar:force \
        --no-verbose \
        -O "$output" \
        "$url"
      return $?
    }
  '';

in {
  # Exportierte Funktionen
  isoManager = { name, url, stateDir, distroName, variant ? null, version ? null }: ''
    function manage_iso() {
      local iso_dir="${stateDir}/testing/iso"
      local iso_name="${name}.iso"
      local iso_path="$iso_dir/$iso_name"
      
      function validate_iso() {
        local path="$1"
        ${validateIso "$1"}
      }

      if [ -f "$iso_path" ]; then
        echo "Validating existing ISO..." >&2
        if ! validate_iso "$iso_path"; then
          echo "❌ Existing ISO validation failed, details above" >&2
          rm -f "$iso_path"
        else
          echo "✓ Existing ISO is valid" >&2
          printf '%s' "$iso_path"
          return 0
        fi
      fi
      
      mkdir -p "$iso_dir"
      echo "📥 Downloading $distroName ISO..." >&2
      ${pkgs.wget}/bin/wget \
        --progress=bar:force \
        --show-progress \
        -O "$iso_path" \
        "${toString url}" >&2
        
      echo "Validating downloaded ISO..." >&2
      if ! validate_iso "$iso_path"; then
        echo "❌ Downloaded ISO is corrupt!" >&2
        rm -f "$iso_path"
        return 1
      fi

      printf '%s' "$iso_path"
      return 0
    }
    manage_iso
  '';
}