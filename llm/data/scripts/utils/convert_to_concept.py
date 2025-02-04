#!/usr/bin/env python3
import json
import os
from pathlib import Path

def convert_to_concept_format(input_file: Path, output_file: Path):
    """Convert raw dataset files to concept format."""
    concepts = []
    
    with open(input_file, 'r') as f:
        for line in f:
            try:
                data = json.loads(line.strip())
                
                # Extract concept and explanation based on file format
                if "question" in data and "answer" in data:
                    concept = data["question"]
                    explanation = data["answer"]
                    
                    # Add category if available
                    if "category" in data:
                        explanation = f"[{data['category']}]\n{explanation}"
                    
                    concepts.append({
                        "concept": concept,
                        "explanation": explanation
                    })
            except json.JSONDecodeError:
                print(f"Warning: Skipping invalid JSON line in {input_file}")
                continue
    
    # Write to output file
    output_file.parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, 'w') as f:
        for concept in concepts:
            json.dump(concept, f)
            f.write('\n')

def main():
    # Setup paths
    raw_dir = Path("/home/fr4iser/Documents/Git/NixOsControlCenter/llm/data/raw")
    processed_dir = Path("/home/fr4iser/Documents/Git/NixOsControlCenter/llm/data/processed/datasets")
    
    # Map input files to output locations
    file_mapping = {
        "flake_datasets.jsonl": processed_dir / "concepts" / "flake_concepts.jsonl",
        "home_manager_datasets.jsonl": processed_dir / "concepts" / "home_manager_concepts.jsonl",
        "nix_datasets.jsonl": processed_dir / "concepts" / "nix_concepts.jsonl",
        "nixos_datasets.jsonl": processed_dir / "concepts" / "nixos_concepts.jsonl",
        "nixpkgs_datasets.jsonl": processed_dir / "concepts" / "nixpkgs_concepts.jsonl",
        "what_is_nixos.jsonl": processed_dir / "concepts" / "basic_nixos_concepts.jsonl"
    }
    
    # Process each file
    for input_name, output_path in file_mapping.items():
        input_path = raw_dir / input_name
        if input_path.exists():
            print(f"Converting {input_name} to concept format...")
            convert_to_concept_format(input_path, output_path)
            print(f"Created {output_path}")
        else:
            print(f"Warning: Input file {input_path} not found")

if __name__ == "__main__":
    main()
