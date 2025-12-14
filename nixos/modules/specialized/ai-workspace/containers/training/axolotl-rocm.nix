{ config, lib, pkgs, ... }:

let
  dataDir = "/var/lib/ai-workspace";
  trainingDir = "${dataDir}/training";
  modelsDir = "${dataDir}/models";
  configDir = "${trainingDir}/config";
  
  setupScript = pkgs.writeText "setup_config.py" ''
    import requests
    import yaml
    import os
    import json
    import time
    from huggingface_hub import snapshot_download
    from transformers import AutoTokenizer

    def wait_for_ollama():
        print("Warte auf Ollama...")
        for _ in range(30):
            try:
                response = requests.get("http://localhost:11434/api/tags")
                if response.status_code == 200:
                    return True
            except:
                pass
            time.sleep(1)
        return False

    def get_model_info(model_name):
        try:
            response = requests.post("http://localhost:11434/api/show", 
                json={"name": model_name})
            return response.json()
        except Exception as e:
            print(f"Fehler beim Abrufen der Modellinformationen: {e}")
            return None

    def setup_tokenizer(model_path, base_model="codellama/CodeLlama-7b-hf"):
        print(f"Lade Tokenizer von {base_model}...")
        try:
            tokenizer = AutoTokenizer.from_pretrained(base_model)
            tokenizer.save_pretrained(model_path)
            print("Tokenizer erfolgreich gespeichert!")
            return True
        except Exception as e:
            print(f"Fehler beim Laden des Tokenizers: {e}")
            return False

    def extract_model(model_name):
        print(f"Extrahiere Modell {model_name}...")
        model_path = f"/workspace/models/{model_name}"
        os.makedirs(model_path, exist_ok=True)

        # Modell-Informationen abrufen
        model_info = get_model_info(model_name)
        if not model_info:
            return None

        # Basis-Modell bestimmen
        if "codellama" in model_name.lower():
            base_model = "codellama/CodeLlama-7b-hf"
        elif "llama2" in model_name.lower():
            base_model = "meta-llama/Llama-2-7b-hf"
        else:
            base_model = "codellama/CodeLlama-7b-hf"  # Fallback

        # Config erstellen
        config = {
            "architectures": ["LlamaForCausalLM"],
            "model_type": "llama",
            "torch_dtype": "float16",
            "transformers_version": "4.36.0",
            "vocab_size": 32000
        }

        # Config speichern
        with open(f"{model_path}/config.json", "w") as f:
            json.dump(config, f, indent=2)

        # Tokenizer herunterladen und einrichten
        if not setup_tokenizer(model_path, base_model):
            print("Fehler beim Einrichten des Tokenizers!")
            return None

        # GGUF Modell kopieren
        print("Kopiere GGUF Modell...")
        os.system(f"cp /root/.ollama/{model_name}/model.gguf {model_path}/model.gguf")
        
        return model_path

    def create_config(model_path):
        config = {
            "base_model": model_path,
            "model_type": "AutoModelForCausalLM",
            "tokenizer_type": "AutoTokenizer",
            
            "output_dir": "/workspace/models/nixos-assistant",
            "hub_model_id": "nixos-assistant",
            
            # Dataset Konfiguration
            "dataset_prepared_path": "/workspace/data/prepared",
            "datasets": [
                {
                    "type": "alpaca",
                    "path": "/workspace/data/nixos/training.json",
                    "data_files": "/workspace/data/nixos/training.json"
                }
            ],
                    
            # Training Parameter für GPU
            "micro_batch_size": 4,  # Erhöht für GPU
            "gradient_accumulation_steps": 4,
            "num_epochs": 3,
            "learning_rate": 2e-4,
            
            # LoRA Parameter bleiben gleich
            "adapter": "lora",
            "lora_r": 8,
            "lora_alpha": 16,
            "lora_dropout": 0.05,
            
            # GPU/ROCm spezifische Einstellungen
            "load_in_8bit": True,
            "load_in_4bit": False,
            "mixed_precision": "bf16",  # ROCm unterstützt bf16
            "bf16": True,
            "fp16": False,
            "device": "cuda",  # Wichtig: für ROCm muss es "cuda" sein
            "device_map": "auto",
            
            # Flash Attention aktivieren
            "flash_attention": True,
            "flash_attn": True,
            "use_flash_attention": True,
            "use_flash_attn": True,
            
            # Export bleibt gleich
            "trust_remote_code": True,
            "export_formats": ["gguf"]
        }
        
        config_path = "/workspace/config/axolotl_config.yml"
        os.makedirs(os.path.dirname(config_path), exist_ok=True)
        with open(config_path, "w") as f:
            yaml.dump(config, f, sort_keys=False, default_flow_style=False)
        
        return config_path


    def main():
        if not wait_for_ollama():
            print("Ollama nicht erreichbar!")
            return
        
        print("Hole Modell-Liste...")
        response = requests.get("http://localhost:11434/api/tags")
        models = response.json().get("models", [])
        
        if not models:
            print("Keine Ollama Modelle gefunden!")
            return
        
        print(f"Gefundene Modelle: {models}")
        model_name = models[0]["name"]
        
        # Modell extrahieren
        model_path = extract_model(model_name)
        if not model_path:
            print("Fehler beim Extrahieren des Modells!")
            return
            
        data_dir = "/workspace/data/nixos"
        prepared_dir = "/workspace/data/prepared"
        os.makedirs(data_dir, exist_ok=True)
        os.makedirs(prepared_dir, exist_ok=True)
        
        data_file = f"{data_dir}/training.json"

        if not os.path.exists(data_file):
            print("Erstelle Beispiel-Trainingsdatei...")
            example_data = [
                {
                    "instruction": "Wie installiere ich NixOS?",
                    "input": "",
                    "output": "Um NixOS zu installieren, folgen Sie diesen Schritten:\n1. ISO herunterladen\n2. Boot-Medium erstellen\n3. Von USB booten\n4. Partitionen einrichten\n5. System konfigurieren\n6. Installation durchführen"
                },
                {
                    "instruction": "Was ist der Unterschied zwischen NixOS und anderen Linux-Distributionen?",
                    "input": "",
                    "output": "NixOS unterscheidet sich durch sein deklaratives Konfigurationssystem und den Nix-Paketmanager. Alle Systemkonfigurationen werden in einer einzelnen Datei definiert, was Reproduzierbarkeit und atomare Updates ermöglicht."
                }
            ]
            
            print(f"Schreibe Daten in: {data_file}")
            with open(data_file, "w") as f:
                for item in example_data:
                    f.write(json.dumps(item) + "\n")
            
            print(f"Beispiel-Trainingsdatei erstellt in {data_file}")
        
        # Konfiguration erstellen
        config_path = create_config(model_path)
        print(f"Konfiguration erstellt in: {config_path}")

    if __name__ == "__main__":
        main()
  '';

in
{
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      axolotl = {
        # ROCm-kompatibles Base Image
        image = "docker.io/rocm/pytorch:latest";
                
        cmd = [ 
            "/bin/sh" 
            "-c" 
            ''
            # System-Pakete aktualisieren
            apt-get update && \
            apt-get install -y git python3-pip python3-venv build-essential && \
            
            # Cleanup
            rm -rf /workspace/axolotl/* && \
            rm -rf /root/.cache/pip && \
            
            # Virtuelles Environment erstellen
            python3 -m venv /workspace/venv && \
            . /workspace/venv/bin/activate && \
            
            # Basis-Dependencies
            pip install --no-cache-dir -U pip setuptools wheel && \
            
            # PyTorch Installation
            pip install --no-cache-dir \
                torch==2.2.0+rocm5.7 \
                torchvision==0.17.0+rocm5.7 \
                --index-url https://download.pytorch.org/whl/rocm5.7 && \
            
            # Transformers und Dependencies mit festen Versionen
            pip install --no-cache-dir \
                transformers==4.36.2 \
                accelerate==0.25.0 \
                einops==0.7.0 \
                wandb==0.16.1 \
                scipy==1.11.4 \
                sentencepiece==0.1.99 \
                protobuf==4.25.1 \
                datasets==2.15.0 && \
            
            # Bitsandbytes mit ROCm Support
            cd /workspace && \
            git clone https://github.com/TimDettmers/bitsandbytes.git && \
            cd bitsandbytes && \
            ROCM_HOME=/opt/rocm \
            PYTORCH_ROCM_ARCH=gfx1030 \
            make hip && \
            pip install . && \
            cd .. && \
            
            # Axolotl Installation
            cd /workspace && \
            git clone --depth 1 https://github.com/OpenAccess-AI-Collective/axolotl.git && \
            cd axolotl && \
            pip install -e . && \
            cd .. && \
            
            # Setup und Training
            python /workspace/setup_config.py && \
            axolotl train /workspace/config/axolotl_config.yml
            ''
        ];
        
        volumes = [
          "${trainingDir}:/workspace/data"
          "${modelsDir}:/workspace/models"
          "${configDir}:/workspace/config"
          "${setupScript}:/workspace/setup_config.py"
          "/var/lib/ai-workspace/ollama:/root/.ollama"
          "/dev/dri:/dev/dri"
        ];
        
        environment = {
          "OLLAMA_HOST" = "http://localhost:11434";
          # ROCm settings
          "HSA_OVERRIDE_GFX_VERSION" = "10.3.0";
          "ROCR_VISIBLE_DEVICES" = "0";
          "HIP_VISIBLE_DEVICES" = "0";
          "PYTORCH_HIP_ALLOC_CONF" = "max_split_size_mb:512";
          "AXOLOTL_BACKEND" = "ROCm";
          "TORCH_DEVICE" = "hip";
          
          # Vulkan settings für bessere Performance
          "AMD_VULKAN_ICD" = "RADV";
          "RADV_PERFTEST" = "aco";
          
          # Debug
          "AXOLOTL_DEBUG" = "1";
        };
        
        extraOptions = [
          "--network=host"
          "--device=/dev/dri"
          "--security-opt=seccomp=unconfined"
        ];
        dependsOn = [ "ollama" ];
        autoStart = true;
      };
    };
  };

  # Rest bleibt gleich
  config.system.activationScripts.trainingSetup = ''
    mkdir -p ${trainingDir}
    mkdir -p ${modelsDir}
    mkdir -p ${configDir}
  '';
}