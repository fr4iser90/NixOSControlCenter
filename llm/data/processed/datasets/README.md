# NixOS Training Datasets

This directory contains the processed datasets used for training the NixOS model. The datasets are organized into different categories, each serving a specific purpose in training the model.

## Directory Structure

```
datasets/
├── concepts/              # Basic and advanced NixOS concepts
├── tasks/                # Training tasks and exercises
├── examples/             # Practical examples and use cases
├── troubleshooting/      # Troubleshooting guides and solutions
└── optimization/         # System optimization datasets
```

## Dataset Formats

### 1. Concepts Dataset (`concepts/`)
Basic and advanced NixOS concepts in JSONL format:
```json
{
    "concept": "String: The NixOS concept to explain",
    "explanation": "String: Detailed explanation of the concept"
}
```

### 2. Training Tasks (`tasks/`)
Training tasks and exercises in JSONL format:
```json
{
    "input": "String: The task or question to solve",
    "output": "String: The solution or answer"
}
```

### 3. Examples Dataset (`examples/`)
Practical examples in JSONL format:
```json
{
    "category": "String: Category of the example",
    "examples": [
        {
            "title": "String: Title of the example",
            "description": "String: What the example demonstrates",
            "commands": ["String array: List of commands to execute"],
            "explanation": "String: Detailed explanation of the example"
        }
    ]
}
```

### 4. Troubleshooting Dataset (`troubleshooting/`)
Troubleshooting guides in JSONL format:
```json
{
    "issue": "String: Description of the problem",
    "steps": ["String array: Step-by-step solution"],
    "common_causes": ["String array: Common causes of the issue"]
}
```

### 5. Optimization Dataset (`optimization/`)
System optimization examples in JSON format:
```json
{
    "input": {
        "hardware_profile": {
            "cpu_model": "String: CPU model",
            "gpu_model": "String: GPU model",
            "memory_gb": "Integer: RAM in GB",
            "storage_type": "String: Storage type"
        },
        "performance_metrics": {
            "cpu_usage": "Float: CPU usage percentage",
            "memory_usage": {
                "percent": "Float: Memory usage percentage"
            },
            "disk_io": {
                "read_bytes": "Integer: Bytes read",
                "write_bytes": "Integer: Bytes written"
            }
        },
        "requirements": {
            "purpose": "String: System purpose",
            "priorities": ["String array: Performance priorities"]
        },
        "current_config": {
            "content": "String: Current NixOS configuration"
        }
    },
    "output": {
        "optimized_config": {
            "content": "String: Optimized NixOS configuration"
        },
        "rationale": "String: Explanation of optimizations"
    }
}
```

## Usage

1. All datasets are used by the training script at `llm/data/scripts/training/train_model.py`
2. The model processes these datasets into question-answer pairs in the format:
   ```
   ### Question: [prompt]

   ### Answer: [response]
   ```
3. Each dataset type is processed differently to create appropriate training pairs

## Contributing New Data

When adding new data:
1. Follow the exact format for each dataset type
2. Use JSONL format for all files except optimization datasets
3. Place files in the appropriate category directory
4. Ensure all JSON is properly formatted and validated
5. Include comprehensive explanations and examples

## Validation

Before training:
1. All datasets are automatically validated during loading
2. Files must be valid JSON/JSONL
3. Required fields must be present
4. Data must follow the specified format for its category