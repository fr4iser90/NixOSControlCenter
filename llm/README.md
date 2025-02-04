# NixOS Control Center LLM Training System

This is a hobby project to train an AI assistant for NixOS. The goal is to create a helpful companion that can assist with everyday NixOS tasks. The model should be able to help with:

- Basic configuration tasks in `configuration.nix`
- Common package commands (`nix-env`, `nixos-rebuild`, `nix-shell`)
- Simple system maintenance
- Troubleshooting common issues

The training system aims to make the model understand NixOS concepts and help users manage their systems more easily.

## 📁 Directory Structure

```
llm/
├── data/                  # Training data and datasets
│   ├── processed/        # Processed and validated datasets
│   └── raw/             # Raw training data
├── scripts/              # Training and utility scripts
│   ├── data/            # Dataset management and processing
│   ├── export/          # Model export utilities (GGUF, Ollama)
│   ├── training/        # Training scripts and configurations
│   ├── utils/           # Utility functions and helpers
│   └── visualization/   # Training metrics visualization
└── models/              # Trained model checkpoints and exports
```

## 🚀 Features

- **Advanced Training Pipeline**
  - Gradient checkpointing for memory efficiency
  - Dynamic batch sizing based on GPU memory
  - Early stopping with model checkpointing
  - Real-time training visualization dashboard

- **Dataset Management**
  - Automated dataset validation
  - Quality metrics computation
  - Continuous improvement system
  - Feedback collection and analysis

- **Model Export**
  - GGUF format conversion for efficiency
  - Ollama integration for easy deployment
  - Quantization options for different use cases

## 🛠️ Requirements

### For Normal Usage (Pre-trained Models)
- Python 3.8+
- Ollama
- 8GB RAM minimum
- 20GB disk space

### For Training
- Python 3.8+
- CUDA-capable GPU (16GB+ VRAM recommended)
- 32GB RAM minimum
- 100GB disk space
- Dependencies:
  ```
  torch>=2.0.0
  transformers>=4.30.0
  datasets>=2.12.0
  accelerate>=0.20.0
  streamlit>=1.24.0
  plotly>=5.14.0
  ```

## 🚦 Quick Start

1. **Setup Environment**
   ```bash
   # Using provided Nix shell
   nix-shell train-shell.nix
   
   # Or using pip
   pip install -r requirements.txt
   ```

2. **Training a Model**

   ```bash
   python model_manager.py
   ```
   or 

   ```bash
   python -m llm.scripts.training.train_nixos_model
   ```
   - Access training visualization at `http://localhost:8501`

3. **Export to Ollama**
   ```bash
   python -m llm.scripts.export.export_model_ollama
   ```

## 📊 Training Visualization

The training process includes a real-time visualization dashboard showing:
- Training and validation loss curves
- Learning rate schedules
- GPU memory usage
- Dataset quality metrics
- Model performance indicators

Access the dashboard at `http://localhost:8501` during training.

## 🔄 Dataset Management

The system includes tools for:
- Validating dataset format and content
- Computing quality metrics
- Collecting training feedback
- Automatically improving datasets

## 📦 Model Export

Supports multiple export formats:
- GGUF (various quantization levels)
- Ollama-compatible format
- Hugging Face model hub format

## 🤝 Contributing

1. Follow the dataset format in `data/processed/datasets/`
2. Use the provided validation tools
3. Test changes with the visualization system
4. Submit improvements via pull requests

## 📝 License

This project is part of the NixOS Control Center and follows its licensing terms.

## 🔗 Related Projects

- [NixOS Control Center](https://github.com/fr4iser90/NixOsControlCenter)
- [Ollama](https://github.com/ollama/ollama)
- [GGUF](https://github.com/ggerganov/ggml)