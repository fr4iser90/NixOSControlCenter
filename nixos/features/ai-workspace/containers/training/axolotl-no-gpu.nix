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
            
            # Training Parameter (korrigiert)
            "micro_batch_size": 1,
            "gradient_accumulation_steps": 4,
            "num_epochs": 3,
            "learning_rate": 2e-4,
            
            # LoRA Parameter
            "adapter": "lora",
            "lora_r": 8,
            "lora_alpha": 16,
            "lora_dropout": 0.05,
            
            # CPU Training
            "load_in_8bit": False,
            "load_in_4bit": False,
            "mixed_precision": False,
            "flash_attention": False,
            "flash_attn": False,
            "use_flash_attention": False,
            "use_flash_attn": False,
            "load_in_8bit": False,
            "load_in_4bit": False,
            "mixed_precision": "no",
            "bf16": False,
            "fp16": False,
            "fsdp": [],
            "device": "cpu",            
            
            # Export
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
        image = "winglian/axolotl:latest";
        cmd = [ 
            "/bin/sh" 
            "-c" 
            ''
            # Cleanup vorhandenes axolotl
            rm -rf /workspace/axolotl/* && \
            # Installation für CPU-only Training
            pip install --no-cache-dir \
                torch==2.5.1 \
                torchvision==0.16.0 \
                torchaudio==2.5.1 \
                --index-url https://download.pytorch.org/whl/cpu && \
            
            # CPU-only Dependencies
            pip install --no-cache-dir \
                transformers \
                accelerate \
                bitsandbytes==0.41.1 \
                --no-deps && \
            
            # Axolotl ohne Flash Attention
            cd /workspace && \
            git clone https://github.com/OpenAccess-AI-Collective/axolotl.git && \
            cd axolotl && \
            pip install -e . --no-deps && \
            cd .. && \
            
            # Setup und Training
            export CUDA_VISIBLE_DEVICES="" && \
            export USE_FLASH_ATTENTION=0 && \
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
          # ENTFERNEN: GPU/ROCm Devices
          # "/dev/dri/card1:/dev/dri/card1"
          # "/dev/dri/renderD128:/dev/dri/renderD128"
        ];
        
        environment = {
          "OLLAMA_HOST" = "http://localhost:11434";
          # ENTFERNEN: Alle ROCm settings
          # "HSA_OVERRIDE_GFX_VERSION" = "10.3.0";
          # "ROCR_VISIBLE_DEVICES" = "0";
          # "HIP_VISIBLE_DEVICES" = "0";
          # "PYTORCH_HIP_ALLOC_CONF" = "max_split_size_mb:512";
          # "AXOLOTL_BACKEND" = "ROCm";
          # "TORCH_DEVICE" = "hip";
          
          # ENTFERNEN: Vulkan settings
          # "AMD_VULKAN_ICD" = "RADV";
          # "RADV_PERFTEST" = "aco";
          
          # Debug kann bleiben
          "AXOLOTL_DEBUG" = "1";
        };
        
        extraOptions = [
          "--network=host"
          # ENTFERNEN: GPU devices
          # "--device=/dev/dri/card1"
          # "--device=/dev/dri/renderD128"
        ];
        dependsOn = [ "ollama" ];
        autoStart = true;
      };
    };
  };

  # Update die Config mit einem öffentlichen Modell
  system.activationScripts.trainingSetup = ''
    mkdir -p ${trainingDir}
    mkdir -p ${modelsDir}
    mkdir -p ${configDir}
  '';
}