{ config, lib, pkgs, ... }:

let
  # Definiere Pfade für persistente Daten
  dataDir = "/var/lib/ai-workspace";
  ollamaDir = "${dataDir}/ollama";
  webuiDir = "${dataDir}/webui";
in

{
  virtualisation = {
    # Docker wird jetzt über Module gesteuert (docker.nix oder docker-rootless.nix)
    # WICHTIG: OCI-Containers brauchen root Docker (weil sie als systemd services laufen)!
    # docker.enable = true;  # DEAKTIVIERT - verwende docker.nix Modul stattdessen
    
    oci-containers = {
      backend = "docker";
      containers = {
        ollama = {
          image = "ollama/ollama:latest";
          ports = [ "11434:11434" ];
          volumes = [
            "${ollamaDir}:/root/.ollama"  # Host-Pfad:Container-Pfad
            "/dev/dri/card1:/dev/dri/card1"
            "/dev/dri/renderD128:/dev/dri/renderD128"
          ];
          environment = {
            "WLR_DRM_DEVICES" = "/dev/dri/card1";
            "AMD_VULKAN_ICD" = "RADV";
            "RADV_PERFTEST" = "aco";
            # ROCm spezifisch
            "HSA_OVERRIDE_GFX_VERSION" = "10.3.0";
            "ROCR_VISIBLE_DEVICES" = "0";
          };
          extraOptions = [
            "--network=host"
            "--device=/dev/dri/card1"
            "--device=/dev/dri/renderD128"
          ];
          dependsOn = [ "milvus" "etcd" "minio" ];
          autoStart = true;
        };

        ollama-webui = {
          image = "ghcr.io/open-webui/open-webui:main";
          ports = [ "8080:8080" ];
          environment = {
            OLLAMA_BASE_URL = "http://127.0.0.1:11434";
            OPENAI_API_KEY = "sk-123456789";
          };
          extraOptions = [
            "--network=host"
          ];
          volumes = [
            "${webuiDir}:/app/backend/data"  # Host-Pfad:Container-Pfad
          ];
          autoStart = true;
        };
      };
    };
  };

  # Erstelle die Verzeichnisse und setze Berechtigungen
  config.system.activationScripts.aiWorkspaceSetup = ''
    mkdir -p ${ollamaDir}
    mkdir -p ${webuiDir}
    chmod 755 ${dataDir}
    chmod 755 ${ollamaDir}
    chmod 755 ${webuiDir}
  '';
}