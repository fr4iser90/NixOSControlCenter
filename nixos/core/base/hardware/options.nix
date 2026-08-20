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
      description = "Hardware module version";
    };

    cpu = lib.mkOption {
      type = lib.types.enum [
        "intel"
        "intel-core"
        "intel-xeon"
        "amd"
        "amd-ryzen"
        "amd-epyc"
        "vm-cpu"
        "none"
      ];
      default = "none";
      description = "CPU type configuration";
    };

    gpu = lib.mkOption {
      type = lib.types.enum [
        "nvidia"
        "amd"
        "intel"
        "nvidia-intel"
        "nvidia-amd"
        "intel-igpu"
        "nvidia-sli"
        "amd-crossfire"
        "nvidia-optimus"
        "vm-gpu"
        "amd-intel"
        "qxl-virtual"
        "virtio-virtual"
        "basic-virtual"
        "amd-amd"
        "jetson"
        "none"
      ];
      default = "none";
      description = "GPU type configuration (jetson = NVIDIA Jetpack / Tegra, not desktop nvidia)";
    };

    # Jetpack / Orin (only used when gpu = "jetson"; flake imports jetpack-nixos)
    jetpack = {
      som = lib.mkOption {
        type = lib.types.enum [
          "generic"
          "orin-agx"
          "orin-agx-industrial"
          "orin-nx"
          "orin-nano"
          "thor-agx"
          "thor-agx-t4000"
          "xavier-agx"
          "xavier-agx-industrial"
          "xavier-nx"
          "xavier-nx-emmc"
        ];
        default = "orin-nano";
        description = "Jetson SoM for hardware.nvidia-jetpack.som";
      };

      carrierBoard = lib.mkOption {
        type = lib.types.enum [ "generic" "devkit" "xavierNxDevkit" ];
        default = "devkit";
        description = "Jetson carrier board";
      };

      super = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Orin NX/Nano super mode";
      };

      containerToolkit = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable hardware.nvidia-container-toolkit (Docker/Podman GPU on Tegra)";
      };

      nvpmodelProfile = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Optional services.nvpmodel.profileNumber (null = leave jetpack defaults)";
      };
    };

    ram = {
      sizeGB = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "RAM size in GB (null = auto-detect via system-checks, will be set before module loads)";
      };
    };
  };
}

