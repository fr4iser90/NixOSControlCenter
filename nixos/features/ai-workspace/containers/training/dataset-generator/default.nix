{ config, lib, pkgs, ... }:

let
  datasetGeneratorScript = pkgs.writeScriptBin "generate-datasets" (builtins.readFile ./generate_datasets.py);
  
  # Control script für einfache Bedienung
  controlScript = pkgs.writeScriptBin "ai-dataset" ''
    #!${pkgs.bash}/bin/bash
    
    if [ $# -lt 1 ]; then
      echo "Usage: ai-dataset <command>"
      echo ""
      echo "Commands:"
      echo "  generate-from-config   - Generate datasets from local NixOS config"
      echo "  fetch-from-docs        - Fetch and parse NixOS documentation"
      echo "  analyze-community      - Analyze community configurations"
      echo ""
      exit 1
    fi
    
    ${datasetGeneratorScript}/bin/generate-datasets $@
  '';

in {
  environment.systemPackages = [ controlScript ];
  
  # Container für Dataset-Generierung
  virtualisation.oci-containers.containers.dataset-generator = {
    image = "python:3.10";
    volumes = [
      "/var/lib/ai-workspace/training:/workspace/datasets"
      "${./generate_datasets.py}:/app/generate_datasets.py"
      "${./utils}:/app/utils"  # Hilfs-Module
      "/etc/nixos:/nixos-config:ro"  # Lokale NixOS-Config readonly
    ];
    cmd = [ "python3" "/app/generate_datasets.py" ];
    autoStart = false;
  };
}