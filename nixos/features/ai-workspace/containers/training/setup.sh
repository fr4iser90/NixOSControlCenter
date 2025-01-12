#!/bin/bash

# Erstelle benötigte Verzeichnisse
mkdir -p /var/lib/ai-workspace/pip-cache
mkdir -p /var/lib/ai-workspace/site-packages
chmod 777 /var/lib/ai-workspace/pip-cache
chmod 777 /var/lib/ai-workspace/site-packages

# Prüfe Setup-Status in persistentem Volume
if [ ! -f /var/lib/ai-workspace/.setup_complete ]; then
  echo "Installiere Python-Pakete..."
  
  # Installiere pip
  curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
  python3 get-pip.py --force-reinstall
  rm get-pip.py
  
  # Installiere Python-Pakete
  python3 -m pip install --index-url https://download.pytorch.org/whl/rocm5.6 torch==2.1.0
  python3 -m pip install transformers==4.31.0 datasets==2.14.0 accelerate==0.21.0 evaluate safetensors
  
  touch /var/lib/ai-workspace/.setup_complete
fi