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

We provide a system requirements checker to help you verify your setup. Run it with:
```bash
python scripts/utils/system_check.py
```

Requirements vary by platform:

#### NVIDIA Jetson Devices
- Python 3.8 or higher
- PyTorch: Download from [NVIDIA's PyTorch for Jetson](https://developer.nvidia.com/embedded/downloads#?search=pytorch)
- RAM: 7GB+ (Nano/NX), 8GB+ (Orin)
- 20GB available disk space
- Ollama (optional, for model deployment)

#### Standard Platforms (PC/Server)
- Python 3.8 or higher
- PyTorch 2.2.0: `pip install torch==2.2.0`
- RAM: 8GB+ (16GB+ recommended)
- 20GB available disk space
- Ollama (for model deployment)

The system checker will automatically detect your platform and provide appropriate installation instructions.

### For Training
- Python 3.8+
- CUDA-capable GPU (16GB+ VRAM recommended)
- 32GB RAM minimum
- 100GB disk space
- Dependencies:
  ```
  transformers>=4.30.0
  datasets>=2.12.0
  accelerate>=0.20.0
  streamlit>=1.24.0
  plotly>=5.14.0
  ```

<details>
<summary>📦 Package Explanations</summary>

- **Core ML & Training:**
  <details>
  <summary>🤖 transformers>=4.40.0</summary>
  
  Hugging Face Transformers library providing pre-trained models (GPT, BERT, LLaMA, etc.) for NLP tasks like text generation, classification, and translation. Essential for our model architecture and training pipeline.
  </details>

  <details>
  <summary>🔥 torch>=2.2.0</summary>
  
  PyTorch deep learning framework. Provides the foundation for neural network training, GPU acceleration, and automatic differentiation.
  </details>

  <details>
  <summary>📊 datasets>=2.18.0</summary>
  
  Hugging Face Datasets library for efficient data loading, processing, and management of training datasets.
  </details>

  <details>
  <summary>🚀 accelerate>=0.27.0</summary>
  
  Hugging Face Accelerate for easy distributed training and mixed precision, making training faster and more memory efficient.
  </details>

- **Model & Data Management:**
  <details>
  <summary>🔄 huggingface-hub>=0.20.0</summary>
  
  Interface with Hugging Face's model hub for model sharing and version management.
  </details>

  <details>
  <summary>🦙 llama-cpp-python>=0.2.56</summary>
  
  Python bindings for llama.cpp, enabling efficient inference and quantization of LLaMA-based models.
  </details>

  <details>
  <summary>📈 psutil>=5.9.0</summary>
  
  System monitoring utilities for tracking CPU, memory, and GPU usage during training.
  </details>

- **Visualization & Monitoring:**
  <details>
  <summary>📊 streamlit>=1.29.0</summary>
  
  Creates interactive web dashboards for real-time training monitoring and model evaluation.
  </details>

  <details>
  <summary>📈 plotly>=5.18.0</summary>
  
  Interactive plotting library for visualizing training metrics and model performance.
  </details>

  <details>
  <summary>📉 pandas>=2.2.0</summary>
  
  Data manipulation and analysis library for processing training logs and metrics.
  </details>

- **Additional Utilities:**
  <details>
  <summary>☁️ wordcloud>=1.9.3</summary>
  
  Generates word clouds for visualizing token distributions and model vocabulary.
  </details>

  <details>
  <summary>🕸️ networkx>=3.2.1</summary>
  
  Graph theory library for analyzing and visualizing model architecture and attention patterns.
  </details>

  <details>
  <summary>📊 matplotlib>=3.8.2</summary>
  
  Basic plotting library for static visualizations and exports.
  </details>

  <details>
  <summary>🔑 PyGithub>=2.1.1</summary>
  
  GitHub API integration for dataset collection and version management.
  </details>

  <details>
  <summary>📝 PyYAML>=6.0.1</summary>
  
  YAML parser for configuration files and model settings.
  </details>

  <details>
  <summary>🌐 requests>=2.31.0</summary>
  
  HTTP library for API interactions and data downloads.
  </details>

  <details>
  <summary>❓ inquirer>=3.1.3</summary>
  
  Interactive command-line interface for training configuration and model management.
  </details>

</details>

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