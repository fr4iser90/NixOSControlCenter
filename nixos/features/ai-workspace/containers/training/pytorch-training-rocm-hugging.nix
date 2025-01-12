{ config, lib, pkgs, ... }:

let
  dataDir = "/var/lib/ai-workspace";
  trainingDir = "${dataDir}/training";
  modelsDir = "${dataDir}/models";
  cacheDir = "${dataDir}/cache";
  offloadDir = "${dataDir}/offload";

  setupScript = pkgs.writeScript "setup.sh" ''
    ${builtins.readFile ./setup.sh}
  '';

  controlScript = pkgs.writeScriptBin "ai-train" ''
    #!${pkgs.bash}/bin/bash
    
    if [ $# -lt 1 ]; then
      echo "Verwendung: ai-train <command> <model_name> [dataset_path]"
      echo ""
      echo "Befehle:"
      echo "  train   <model>  - Lade und trainiere ein Modell"
      echo "  test    <model>  - Teste ein Modell"
      echo "  status          - Zeige Status"
      echo "  stop            - Stoppe laufendes Training"
      echo ""
      echo "Beispiel:"
      echo "  ai-train train deepseek-ai/deepseek-coder-1.3b-base /workspace/datasets/nixos/01_basic_flake.json"
      exit 1
    fi
    
    COMMAND=$1
    MODEL=$2
    DATASET=$3
    
    case "$COMMAND" in
      train)
        echo "Starting training with model: $MODEL and dataset: $DATASET"
        ${pkgs.docker}/bin/docker exec ai-model-trainer python3 /workspace/ai-trainer.py train "$MODEL" "$DATASET"
        ;;
      test)
        echo "Testing model: $MODEL"
        ${pkgs.docker}/bin/docker exec ai-model-trainer python3 /workspace/ai-trainer.py test "$MODEL"
        ;;
      status)
        echo "Container Status:"
        ${pkgs.docker}/bin/docker ps -f name=ai-model-trainer
        echo ""
        echo "GPU Status:"
        ${pkgs.rocmPackages.rocm-smi}/bin/rocm-smi
        ;;
      stop)
        echo "Stopping training process..."
        ${pkgs.docker}/bin/docker exec ai-model-trainer pkill -f "python3 /workspace/ai-trainer.py"
        ;;
      *)
        echo "Unknown command: $COMMAND"
        exit 1
        ;;
    esac
  '';

  trainingScript = pkgs.writeText "ai-trainer.py" ''
    ${builtins.readFile ./trainer.py}
  '';

in {
  environment.systemPackages = [ controlScript ];
  
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      ai-model-trainer = {
        image = "rocm/pytorch:latest-release";
        autoStart = true;
        cmd = [ 
          "bash"
          "-c"
          "/workspace/setup.sh && tail -f /dev/null"
        ];
    
        volumes = [
          "${dataDir}:${dataDir}"
          "${modelsDir}:/workspace/models"
          "${trainingDir}:/workspace/datasets"
          "${trainingScript}:/workspace/ai-trainer.py"
          "${setupScript}:/workspace/setup.sh"
          "/dev/dri:/dev/dri"
          "/var/lib/ai-workspace/pip-cache:/root/.cache/pip"
          "/var/lib/ai-workspace/site-packages:/opt/conda/envs/py_3.10/lib/python3.10/site-packages"
          "${cacheDir}:/root/.cache/huggingface"
        ];
        
        environment = {
          "HSA_OVERRIDE_GFX_VERSION" = "10.3.0";
          "ROCR_VISIBLE_DEVICES" = "0";
          "HIP_VISIBLE_DEVICES" = "0";
          "PYTORCH_HIP_ALLOC_CONF" = "max_split_size_mb:512";
        };
        
        extraOptions = [
          "--device=/dev/kfd"
          "--device=/dev/dri"
          "--group-add=video"
          "--security-opt=seccomp=unconfined"
        ];
      };
    };
  };

  system.activationScripts.trainingSetup = ''
    mkdir -p ${modelsDir}
    mkdir -p ${trainingDir}
    mkdir -p ${cacheDir}
    mkdir -p ${offloadDir}
    mkdir -p /var/lib/ai-workspace/pip-cache
    mkdir -p /var/lib/ai-workspace/site-packages
    chmod 777 /var/lib/ai-workspace/pip-cache
    chmod 777 /var/lib/ai-workspace/site-packages
    chmod 777 ${offloadDir}
  '';
}