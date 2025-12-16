{ pkgs, lib, ... }:

rec {
  # Prüfe ob Modul versioniert ist (hat options.nix)
  hasVersion = modulePath: builtins.pathExists "${toString modulePath}/options.nix";
  
  # Extrahiere Version aus options.nix (SOURCE)
  # Gibt Bash-Script zurück, das Version ausgibt
  getSourceVersionScript = modulePath: ''
    # Extrahiere Version aus options.nix
    OPTIONS_FILE="${toString modulePath}/options.nix"
    if [ -f "$OPTIONS_FILE" ]; then
      # Grep: moduleVersion = "X.Y"
      VERSION=$(grep -m 1 'moduleVersion =' "$OPTIONS_FILE" 2>/dev/null | sed 's/.*moduleVersion = "\([^"]*\)".*/\1/' || echo "unknown")
      echo -n "$VERSION"
    else
      echo -n "unknown"
    fi
  '';
  
  # Extrahiere Version aus config.nix (TARGET)
  # Gibt Bash-Script zurück, das Version ausgibt
  getTargetVersionScript = modulePath: configName: ''
    # Extrahiere Version aus config.nix
    CONFIG_FILE="${toString modulePath}/${configName}/config.nix"
    if [ -f "$CONFIG_FILE" ]; then
      # Grep: _version = "X.Y"
      VERSION=$(grep -m 1 '_version =' "$CONFIG_FILE" 2>/dev/null | sed 's/.*_version = "\([^"]*\)".*/\1/' || echo "unknown")
      echo -n "$VERSION"
    else
      echo -n "unknown"
    fi
  '';
  
  # Vergleiche Versionen (gibt Bash-Script zurück, das 0/1 exit code hat)
  # Exit 0 wenn v1 != v2 (Migration nötig), Exit 1 wenn v1 == v2 (keine Migration)
  versionsDifferScript = v1: v2: ''
    if [ "$v1" = "unknown" ] || [ "$v2" = "unknown" ]; then
      # Eine Version ist unbekannt → Migration nötig
      exit 0
    fi
    if [ "$v1" != "$v2" ]; then
      # Versionen unterschiedlich → Migration nötig
      exit 0
    else
      # Versionen gleich → keine Migration
      exit 1
    fi
  '';
  
  # Prüfe ob Migration nötig ist (gibt Bash-Script zurück)
  # Exit 0 wenn Migration nötig, Exit 1 wenn nicht
  migrationNeededScript = sourceModule: targetModule: moduleName: forceMigration: ''
    # Prüfe ob SOURCE versioniert ist
    if [ ! -f "${toString sourceModule}/options.nix" ]; then
      # SOURCE hat keine Version → Stufe 0 → 1 Migration
      exit 0
    fi
    
    # Prüfe ob TARGET config file hat
    if [ ! -f "${toString targetModule}/${moduleName}/config.nix" ]; then
      # TARGET hat keine config file → Migration nötig (erstelle Default)
      exit 0
    fi
    
    # Beide haben Versionen → vergleiche
    SOURCE_VERSION=$(${getSourceVersionScript sourceModule})
    TARGET_VERSION=$(${getTargetVersionScript targetModule moduleName})
    
    if [ "$SOURCE_VERSION" = "unknown" ] || [ "$TARGET_VERSION" = "unknown" ]; then
      # Eine Version ist unbekannt → Migration nötig
      exit 0
    fi
    
    if [ "$SOURCE_VERSION" != "$TARGET_VERSION" ]; then
      # Versionen unterschiedlich → Migration nötig
      exit 0
    fi
    
    if [ "${if forceMigration then "true" else "false"}" = "true" ]; then
      # Migration forciert → Migration nötig
      exit 0
    fi
    
    # Keine Migration nötig
    exit 1
  '';
}

