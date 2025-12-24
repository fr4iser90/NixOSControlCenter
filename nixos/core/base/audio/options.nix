{ lib, getCurrentModuleMetadata, ... }:

let
  # Finde eigenes Modul aus PFAD! KEIN hardcoded Name!
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Audio module version";
    };

    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable audio system";
    };

    system = lib.mkOption {
      type = lib.types.enum [ "pipewire" "pulseaudio" "alsa" "none" ];
      default = "pipewire";
      description = "Audio system to use";
    };
  };
}

