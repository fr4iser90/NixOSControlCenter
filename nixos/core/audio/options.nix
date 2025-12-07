{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.audio = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
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

