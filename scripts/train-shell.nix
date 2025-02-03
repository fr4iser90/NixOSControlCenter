{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pip
    numpy
    pandas
    requests
    psutil
    pyyaml
    tqdm
  ]);

  basePackages = [
    pythonEnv
    pkgs.git
  ];

  hooks = {
    shellHook = ''
      # Erstelle und aktiviere venv
      python -m venv .venv
      source .venv/bin/activate
      
      # Installiere ML-Pakete
      pip install --upgrade pip
      pip install transformers==4.40.0 \
                  torch==2.2.0 \
                  datasets==2.18.0 \
                  accelerate==0.27.0 \
                  huggingface-hub==0.20.0 \
                  llama-cpp-python==0.2.56 \
                  PyGithub==2.1.1
      
      # CUDA support wenn verfügbar
      export LD_LIBRARY_PATH="${pkgs.cudatoolkit}/lib:$LD_LIBRARY_PATH"
      
      echo "NixOS AI Training Environment aktiviert!"
      echo "Python Version: $(python --version)"
      echo "Torch Version: $(python -c 'import torch; print(torch.__version__)')"
      echo "CUDA Verfügbar: $(python -c 'import torch; print(torch.cuda.is_available())')"
    '';
  };

in
pkgs.mkShell {
  name = "NixOsControlCenter-AI-Training-Shell";
  buildInputs = basePackages ++ (if pkgs.stdenv.isLinux then [ pkgs.cudatoolkit ] else []);
  inherit (hooks) shellHook;
}