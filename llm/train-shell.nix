{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  pythonEnv = pkgs.python312;

  basePackages = [
    pythonEnv
    pkgs.git
    pkgs.python312Packages.pip
    pkgs.python312Packages.virtualenv
  ];

  hooks = {
    shellHook = ''
      echo "Initialisiere Python-Umgebung..."
      
      # Lösche alte venv wenn vorhanden
      rm -rf .venv
      
      # Erstelle und aktiviere venv
      ${pythonEnv}/bin/python -m venv .venv
      source .venv/bin/activate
      
      echo "Installiere Python-Pakete..."
      
      # Installiere ML-Pakete
      pip install --upgrade pip
      
      echo "Installiere PyTorch..."
      pip install torch --index-url https://download.pytorch.org/whl/cpu
      
      echo "Installiere weitere ML-Pakete..."
      pip install numpy==1.26.3 \
                  pandas==2.2.0 \
                  transformers==4.36.2 \
                  datasets==2.18.0 \
                  accelerate==0.27.0 \
                  huggingface-hub==0.20.3 \
                  llama-cpp-python==0.2.56 \
                  PyGithub==2.1.1 \
                  peft==0.9.0 \
                  PyYAML==6.0.1 \
                  tqdm==4.66.1 \
                  psutil==5.9.8 \
                  requests==2.31.0 \
                  inquirer==3.1.3
      
      # Überprüfe Installation
      echo "Überprüfe Installation..."
      if python -c "import torch; import transformers; import peft; import inquirer; print('Alle Pakete erfolgreich installiert!')" ; then
          echo "✓ Installation erfolgreich!"
      else
          echo "✗ Installation fehlgeschlagen!"
          exit 1
      fi
      
      # CUDA support wenn verfügbar
      if [ -d "${pkgs.cudatoolkit}/lib" ]; then
        export LD_LIBRARY_PATH="${pkgs.cudatoolkit}/lib:$LD_LIBRARY_PATH"
      fi
      
      echo "NixOS AI Training Environment aktiviert!"
      echo "----------------------------------------"
      echo "Python Version: $(python --version)"
      echo "NumPy Version: $(python -c 'import numpy; print(numpy.__version__)')"
      echo "Torch Version: $(python -c 'import torch; print(torch.__version__)')"
      echo "CUDA Verfügbar: $(python -c 'import torch; print(torch.cuda.is_available())')"
      echo "----------------------------------------"
    '';
  };

in
pkgs.mkShell {
  name = "NixOsControlCenter-AI-Training-Shell";
  buildInputs = basePackages ++ (if pkgs.stdenv.isLinux then [ pkgs.cudatoolkit ] else []);
  inherit (hooks) shellHook;
}