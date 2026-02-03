{ config, lib, pkgs, systemConfig, getModuleConfig, getCurrentModuleMetadata, moduleName, ... }:

let
  colors = import ./colors.nix;

  # Für API: Components mit leerer config importieren (Henne-Ei-Problem lösen)
  coreForApi = import ./core {
    inherit lib colors;
    config = {};  # Leere config für API
  };

  componentsForApi = import ./components {
    inherit lib colors;
    config = {};  # Leere config für API
  };

  interactiveForApi = import ./interactive {
    inherit lib colors;
    config = {};  # Leere config für API
  };

  statusForApi = import ./status {
    inherit lib colors;
    config = {};  # Leere config für API
  };

  # API definition - IMMER verfügbar (bevor cfg verfügbar ist!)
  apiValue = {
    inherit colors;
    inherit (coreForApi) text layout;
    inherit (componentsForApi) lists tables progress boxes;
    inherit (interactiveForApi) prompts spinners;
    inherit (statusForApi) messages;
    badges = statusForApi.badges;
  };

  # Generischen Pfad aus Dateisystem ableiten
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath;  # NO FALLBACKS!

  # ERST JETZT cfg holen
  cfg = getModuleConfig moduleName;

  # Für Implementation: Components mit echter config neu importieren
  core = import ./core {
    inherit lib colors;
    inherit (cfg) config;
  };

  components = import ./components {
    inherit lib colors;
    inherit (cfg) config;
  };

  interactive = import ./interactive {
    inherit lib colors;
    inherit (cfg) config;
  };

  status = import ./status {
    inherit lib colors;
    inherit (cfg) config;
  };


in
{
  config = {
    # API immer verfügbar machen
    ${configPath}.api = apiValue;
  };
}
