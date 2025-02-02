#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from typing import Optional
import torch
from llama_cpp import Llama, LlamaGrammar
from huggingface_hub import hf_hub_download

class NixOSModelExporter:
    def __init__(self, model_path: str, output_dir: str = "models/ollama"):
        self.model_path = Path(model_path)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Default quantization configuration
        self.quantization_config = {
            "q4_0": {"quantize": True, "qtype": "q4_0"},
            "q5_0": {"quantize": True, "qtype": "q5_0"},
            "q8_0": {"quantize": True, "qtype": "q8_0"},
            "f16": {"quantize": False}
        }
        
    def _get_model_basename(self) -> str:
        """Extract model name from path"""
        return self.model_path.name.replace(".bin", "").replace(".pth", "").replace(".pt", "")
    
    def _create_modelfile(self, model_name: str, quantization: str) -> str:
        """Generate Ollama modelfile with metadata"""
        return f"""FROM ./{model_name}.gguf
# Model metadata
LICENSE MIT
AUTHOR fr4iser
SYSTEM \"\"\"
You are a NixOS expert assistant trained on official documentation and community knowledge.
Always provide accurate, up-to-date information about NixOS configuration and administration.
\"\"\"
PARAMETER num_ctx 4096
PARAMETER temperature 0.7
"""
    
    def convert_to_gguf(self, quantization: str = "q4_0") -> Path:
        """Convert HF model to GGUF format with quantization"""
        if not torch.cuda.is_available():
            print("Warning: Converting without GPU acceleration - this may be slow")
            
        model_basename = self._get_model_basename()
        output_path = self.output_dir / f"{model_basename}-{quantization}.gguf"
        
        # Conversion logic
        llm = Llama(
            model_path=str(self.model_path),
            n_ctx=4096,
            n_gpu_layers=-1 if torch.cuda.is_available() else 0,
            verbose=False
        )
        
        # Handle quantization
        if self.quantization_config[quantization]["quantize"]:
            print(f"Quantizing model to {quantization}...")
            llm.quantize(
                model_path=str(output_path),
                q_type=self.quantization_config[quantization]["qtype"],
                dtype="float16" if quantization == "f16" else None
            )
        else:
            llm.save(str(output_path))
            
        # Create modelfile
        modelfile_content = self._create_modelfile(model_basename, quantization)
        modelfile_path = output_path.with_suffix(".Modelfile")
        modelfile_path.write_text(modelfile_content)
        
        print(f"Successfully exported model to {output_path}")
        return output_path
    
    def push_to_ollama(self, model_path: Path):
        """Register model with Ollama using the correct jetson-containers path"""
        model_name = model_path.stem
        ollama_root = Path("/home/fr4iser/jetson-containers/data/models/ollama")
        
        # Create required directories
        blobs_dir = ollama_root / "models/blobs"
        manifests_dir = ollama_root / "models/manifests/registry.ollama.ai/library"
        blobs_dir.mkdir(parents=True, exist_ok=True)
        manifests_dir.mkdir(parents=True, exist_ok=True)

        # Generate SHA256 hash for the model
        import hashlib
        with open(model_path, "rb") as f:
            blob_hash = hashlib.sha256(f.read()).hexdigest()
        
        # Create blob file
        blob_path = blobs_dir / f"sha256-{blob_hash}"
        if not blob_path.exists():
            import shutil
            shutil.copy(model_path, blob_path)
        
        # Create manifest
        manifest = {
            "schemaVersion": 2,
            "mediaType": "application/vnd.ollama.image.model",
            "config": {
                "mediaType": "application/vnd.ollama.image.config",
                "digest": f"sha256:{blob_hash}",
                "size": model_path.stat().st_size
            },
            "layers": [
                {
                    "mediaType": "application/vnd.ollama.image.model",
                    "digest": f"sha256:{blob_hash}",
                    "size": model_path.stat().st_size
                }
            ]
        }
        
        # Save manifest
        manifest_path = manifests_dir / f"{model_name}/latest"
        manifest_path.mkdir(parents=True, exist_ok=True)
        with open(manifest_path / "manifest.json", "w") as f:
            json.dump(manifest, f)
        
        print(f"Model registered in Ollama at {ollama_root}")
        print("Restart Ollama service and use:")
        print(f"ollama run {model_name}")

def main():
    parser = argparse.ArgumentParser(description="Export trained NixOS model to Ollama format")
    parser.add_argument("--model-path", type=str, required=True,
                       help="Path to trained Hugging Face model directory")
    parser.add_argument("--quantization", type=str, default="q4_0",
                       choices=["q4_0", "q5_0", "q8_0", "f16"],
                       help="Quantization level for GGUF conversion")
    
    args = parser.parse_args()
    
    exporter = NixOSModelExporter(args.model_path)
    gguf_path = exporter.convert_to_gguf(args.quantization)
    exporter.push_to_ollama(gguf_path)

if __name__ == "__main__":
    main()