{ lib, pkgs }:

let
  inherit (lib) optionalString;

  # Helper für ISO-Validierung
  validateIso = ''
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
      if echo "$file_type" | grep -iE "ISO 9660|ISO DOS/MBR boot sector|x86 boot sector|bootable disk|UDF filesystem" > /dev/null; then
        echo "Debug: ISO validation passed for $path" >&2
        return 0
      else
        echo "Debug: ISO validation failed - unexpected file type" >&2
        return 1
      fi
    }
  '';

in {
  # Exportierte Funktionen
  # localOnly: skip download; require VM_ISO or ${stateDir}/testing/iso/<name>.iso
  isoManager = { name, url, stateDir, distroName, variant ? null, version ? null, localOnly ? false, isoHint ? null }: ''
    function manage_iso() {
      local iso_dir="${stateDir}/testing/iso"
      local iso_name="${name}.iso"
      local iso_path="$iso_dir/$iso_name"
      local short_name
      short_name=$(echo "${name}" | sed 's/-test$//; s/-.*$//')
      # Also accept distro-named files: win11.iso, win10.iso
      local alt_path="$iso_dir/''${short_name}.iso"

      ${validateIso}
      
      # Prefer explicit override
      if [ -n "''${VM_ISO:-}" ]; then
        if validate_iso "$VM_ISO"; then
          printf '%s' "$VM_ISO"
          return 0
        fi
        echo "❌ VM_ISO is set but invalid: $VM_ISO" >&2
        return 1
      fi

      for candidate in "$iso_path" "$alt_path"; do
        if [ -f "$candidate" ]; then
          echo "Validating existing ISO: $candidate" >&2
          if validate_iso "$candidate"; then
            echo "✓ Existing ISO is valid" >&2
            printf '%s' "$candidate"
            return 0
          else
            echo "❌ Existing ISO validation failed: $candidate" >&2
            ${if localOnly then "return 1" else "rm -f \"$candidate\""}
          fi
        fi
      done

      ${if localOnly then ''
        mkdir -p "$iso_dir" 2>/dev/null || sudo mkdir -p "$iso_dir"
        echo "❌ No local ISO found for $distroName" >&2
        echo "" >&2
        echo "Microsoft does not allow anonymous ISO mirrors. Place an ISO here:" >&2
        echo "  $alt_path" >&2
        echo "  or: $iso_path" >&2
        echo "  or: VM_ISO=/path/to/windows.iso ncc vm test-…-run" >&2
        ${optionalString (isoHint != null) ''
        echo "" >&2
        echo "Download eval ISO: ${isoHint}" >&2
        ''}
        return 1
      '' else ''
        mkdir -p "$iso_dir" 2>/dev/null || sudo mkdir -p "$iso_dir"
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
      ''}
    }
    manage_iso
  '';
}
