import torch
import sys
from transformers import (
    AutoModelForCausalLM, 
    AutoTokenizer,
    TrainingArguments,
    Trainer,
    DataCollatorForLanguageModeling
)
from datasets import Dataset
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_model(model, tokenizer):
    prompt = """### Human: Create a minimal NixOS flake.nix with home-manager that has:
- unstable channel
- one user named 'alice'
- basic development tools

### Assistant:"""
    
    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
    
    print("\nTeste Modell mit Prompt:", prompt)
    outputs = model.generate(
        **inputs,
        max_new_tokens=500,
        temperature=0.7,
        num_return_sequences=1,
        top_p=0.95,
        do_sample=True
    )
    response = tokenizer.decode(outputs[0], skip_special_tokens=True)
    print("\nAntwort:", response)

def train(model_name, dataset_path):
    logger.info(f"Starting training with model {model_name}")
    
    # GPU Check
    device = "cuda" if torch.cuda.is_available() else "cpu"
    if hasattr(torch.backends, "rocm") and torch.backends.rocm.is_available():
        device = "rocm"
    logger.info(f"Using device: {device}")

    # Load model and tokenizer
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForCausalLM.from_pretrained(model_name).to(device)

    # Load and prepare dataset
    with open(dataset_path, 'r') as f:
        data = json.load(f)
    
    # Format dataset
    formatted_data = []
    for item in data:
        text = f"### Human: {item['input']}\n\n### Assistant: {item['output']}"
        formatted_data.append({"text": text})

    dataset = Dataset.from_list(formatted_data)
    
    def tokenize_function(examples):
        return tokenizer(
            examples["text"],
            padding="max_length",
            truncation=True,
            max_length=512,
            return_tensors="pt"
        )

    tokenized_dataset = dataset.map(
        tokenize_function,
        remove_columns=dataset.column_names,
        batched=True
    )

    # Training configuration
    training_args = TrainingArguments(
        output_dir=f"/workspace/models/{model_name.split('/')[-1]}-checkpoints",
        num_train_epochs=3,
        per_device_train_batch_size=4,
        gradient_accumulation_steps=4,
        learning_rate=2e-5,
        warmup_steps=100,
        logging_steps=10,
        save_steps=100,
        fp16=True if device == "cuda" else False,
        report_to="none"
    )

    # Initialize trainer
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=tokenized_dataset,
        data_collator=DataCollatorForLanguageModeling(
            tokenizer=tokenizer,
            mlm=False
        )
    )

    # Train
    try:
        logger.info("Starting training...")
        trainer.train()
        
        logger.info("Saving model...")
        model.save_pretrained(f"/workspace/models/{model_name.split('/')[-1]}-finetuned")
        tokenizer.save_pretrained(f"/workspace/models/{model_name.split('/')[-1]}-finetuned")
        
        logger.info("Training completed successfully!")
    except Exception as e:
        logger.error(f"Training failed: {str(e)}")
        raise

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 3:
        print("Usage: trainer.py train <model_name> <dataset_path>")
        sys.exit(1)
    
    command = sys.argv[1]
    model_name = sys.argv[2]
    dataset_path = sys.argv[3]
    
    if command == "train":
        train(model_name, dataset_path)
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)