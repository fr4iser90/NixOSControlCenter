import sys
from utils.config_parser import parse_nixos_config
from utils.docs_parser import parse_nixos_docs
from utils.community_parser import analyze_community_configs
from utils.quality_check import validate_dataset

def main():
    command = sys.argv[1]
    
    if command == "generate-from-config":
        datasets = parse_nixos_config("/nixos-config")
        save_datasets(datasets, "nixos-config-datasets")
        
    elif command == "fetch-from-docs":
        datasets = parse_nixos_docs()
        save_datasets(datasets, "nixos-docs-datasets")
        
    elif command == "analyze-community":
        datasets = analyze_community_configs()
        save_datasets(datasets, "community-datasets")

def save_datasets(datasets, prefix):
    # Qualitätskontrolle
    validated_datasets = [
        dataset for dataset in datasets 
        if validate_dataset(dataset)
    ]
    
    # In Dateien speichern
    for i, dataset in enumerate(validated_datasets):
        with open(f"/workspace/datasets/{prefix}_{i:03d}.json", "w") as f:
            json.dump(dataset, f, indent=2)

if __name__ == "__main__":
    main()