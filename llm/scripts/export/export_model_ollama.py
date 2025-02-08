#!/usr/bin/env python3
import argparse
import logging
from pathlib import Path
import subprocess
import os
import shutil

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class NixOSModelExporter:
    def __init__(self, model_path: str, output_dir: str = None):
        self.model_path = Path(model_path)
        self.output_dir = Path(output_dir) if output_dir else Path("models/ollama")
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    def _create_modelfile(self, model_name: str) -> str:
        """Generate Ollama modelfile with metadata and NixOS-specific context"""
        return f'''FROM /data/models/{model_name}/model.gguf

LICENSE MIT

TEMPLATE """Below are questions and answers about NixOS concepts.

Question: {{.Input}}
Answer: ["""

SYSTEM """You are a NixOS expert assistant trained on official documentation and community knowledge.
Your responses should:
1. Be accurate and up-to-date about NixOS configuration and administration
2. Include relevant category tags like [Basics], [Package Management], etc.
3. Provide practical examples when appropriate
4. Focus on declarative configuration and reproducibility
5. Reference official NixOS documentation when possible"""

PARAMETER stop "Question:"
PARAMETER stop "]"
PARAMETER num_ctx 4096
PARAMETER temperature 0.8
PARAMETER top_k 40
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1'''

    def _convert_to_gguf(self, model_path: Path, force_rebuild: bool = False) -> Path:
        """Convert model to GGUF format using llama.cpp"""
        logger.info("Converting model to GGUF format with llama.cpp...")
        
        # Clone llama.cpp if not already present
        llama_cpp_path = Path("llama.cpp")
        if not llama_cpp_path.exists():
            logger.info("Cloning llama.cpp repository...")
            result = subprocess.run(
                ["git", "clone", "https://github.com/ggerganov/llama.cpp.git"],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
            )
            logger.info(result.stdout)
        
        # Check for existing convert tool before rebuilding
        possible_locations = [
            llama_cpp_path / "build" / "convert",
            llama_cpp_path / "build" / "bin" / "convert"
        ]
        
        convert_path = None
        for loc in possible_locations:
            if loc.exists() and not force_rebuild:
                convert_path = loc
                logger.info(f"Found existing convert tool at {convert_path}")
                break
                
        if convert_path is None or force_rebuild:
            # Build llama.cpp using CMake
            build_dir = llama_cpp_path / "build"
            if build_dir.exists():
                if force_rebuild:
                    logger.info("Force rebuild requested - removing existing build directory...")
                    shutil.rmtree(build_dir)
                else:
                    logger.info("Build directory exists but convert tool not found - rebuilding...")
                    shutil.rmtree(build_dir)
            
            logger.info("Configuring CMake build...")
            try:
                # First ensure we're in a clean state
                if (llama_cpp_path / "CMakeCache.txt").exists():
                    os.remove(llama_cpp_path / "CMakeCache.txt")
                
                # Configure with specific ARM options for Jetson
                cmake_args = [
                    "cmake",
                    "-B", "build",
                    "-DCMAKE_BUILD_TYPE=Release",
                    "-DLLAMA_NATIVE=OFF",  # Disable native optimizations
                    "-DLLAMA_ARM_NEON=ON",  # Enable NEON
                    "-DCMAKE_VERBOSE_MAKEFILE=ON"  # Enable verbose output
                ]
                
                result = subprocess.run(
                    cmake_args,
                    cwd=llama_cpp_path,
                    check=True,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT
                )
                logger.info(result.stdout)
                
                # Build the convert tool with specific target
                logger.info("Building convert tool (this may take several minutes)...")
                build_result = subprocess.run(
                    ["cmake", "--build", "build", "--target", "convert", "--verbose"],
                    cwd=llama_cpp_path,
                    check=True,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT
                )
                logger.info(build_result.stdout)
                
                # Verify the build output
                if "Error" in build_result.stdout or "error" in build_result.stdout.lower():
                    logger.error("Build completed but errors were detected in output:")
                    logger.error(build_result.stdout)
                    raise RuntimeError("Build completed with errors")
                
            except subprocess.CalledProcessError as e:
                logger.error("Build failed with output:")
                logger.error(e.output)
                # List build directory contents for debugging
                if build_dir.exists():
                    logger.error("Build directory contents:")
                    for root, dirs, files in os.walk(build_dir):
                        for name in files:
                            logger.error(os.path.join(root, name))
                raise RuntimeError(f"Failed to build convert tool: {str(e)}")
            
            # Check for convert tool after building
            convert_path = None
            for loc in possible_locations:
                if loc.exists():
                    convert_path = loc
                    logger.info(f"Found convert tool at {convert_path}")
                    break
            
            if not convert_path:
                logger.error("Could not find convert tool in any of these locations:")
                for loc in possible_locations:
                    logger.error(f"- {loc}")
                if build_dir.exists():
                    logger.error("Contents of build directory:")
                    for root, dirs, files in os.walk(build_dir):
                        for name in files:
                            logger.error(os.path.join(root, name))
                raise FileNotFoundError("Failed to build convert tool")
        
        # Convert to GGUF
        gguf_path = self.output_dir / "model.gguf"
        
        # Copy model files to a temporary directory
        temp_model_dir = self.output_dir / "temp_model"
        temp_model_dir.mkdir(exist_ok=True)
        
        # Copy all files from model_path to temp_model_dir
        logger.info(f"Copying model files from {model_path} to {temp_model_dir}")
        for file in model_path.glob('*'):
            if file.is_file():
                shutil.copy2(file, temp_model_dir)
                logger.info(f"Copied {file.name}")
        
        logger.info("Starting model conversion...")
        result = subprocess.run(
            [
                str(convert_path),
                str(temp_model_dir),
                "--outtype", "f16",
                "--outfile", str(gguf_path)
            ],
            cwd=llama_cpp_path,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )
        logger.info(result.stdout)
        
        # Clean up temp directory
        shutil.rmtree(temp_model_dir)
        
        return gguf_path
    
    def export_to_ollama(self, model_name: str = "nixos-assistant", force_rebuild: bool = False) -> None:
        """Export model to Ollama format"""
        # Convert to GGUF format
        gguf_path = self._convert_to_gguf(self.model_path, force_rebuild)
        
        # Create modelfile
        modelfile_content = self._create_modelfile(model_name)
        modelfile_path = self.output_dir / "Modelfile"
        modelfile_path.write_text(modelfile_content)
        
        try:
            # Copy files to Docker container
            logger.info("Copying model files to Docker container...")
            result = subprocess.run(
                ["docker", "exec", "ollama", "mkdir", "-p", f"/data/models/{model_name}"],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
            )
            logger.info(result.stdout)
            
            # Clean up any existing files
            result = subprocess.run(
                ["docker", "exec", "ollama", "rm", "-rf", f"/data/models/{model_name}/*"],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
            )
            logger.info(result.stdout)
            
            result = subprocess.run(
                ["docker", "cp", str(gguf_path), f"ollama:/data/models/{model_name}/model.gguf"],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
            )
            logger.info(result.stdout)
            
            result = subprocess.run(
                ["docker", "cp", str(modelfile_path), "ollama:/data/models/Modelfile"],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
            )
            logger.info(result.stdout)
            
            # Create model in Docker
            logger.info("Creating model in Docker Ollama...")
            result = subprocess.run(
                ["docker", "exec", "-w", "/data/models", "ollama", "ollama", "create", model_name, "-f", "Modelfile"],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
            )
            logger.info(result.stdout)
            logger.info(f"Successfully created Ollama model: {model_name}")
            logger.info("To use the model:")
            logger.info("1. In Docker: docker exec -it ollama ollama run nixos-assistant")
            logger.info("2. Via API: curl -X POST http://localhost:11434/api/generate -d '{\"model\":\"nixos-assistant\",\"prompt\":\"What is NixOS?\"}'")
        except subprocess.CalledProcessError as e:
            logger.error(f"Error creating Ollama model: {e.stderr}")
            raise

def main():
    parser = argparse.ArgumentParser(description="Export trained NixOS model to Ollama format")
    parser.add_argument("--model-path", type=str, required=True,
                       help="Path to trained model directory")
    parser.add_argument("--model-name", type=str, default="nixos-assistant",
                       help="Name for the exported Ollama model")
    parser.add_argument("--output-dir", type=str,
                       help="Output directory for converted model")
    parser.add_argument("--force-rebuild", action="store_true",
                       help="Force rebuild of llama.cpp convert tool even if it exists")
    
    args = parser.parse_args()
    
    try:
        exporter = NixOSModelExporter(args.model_path, args.output_dir)
        exporter.export_to_ollama(args.model_name, args.force_rebuild)
    except Exception as e:
        logger.error(f"Error during export: {e}")
        logger.exception("Full traceback:")
        raise

if __name__ == "__main__":
    main()