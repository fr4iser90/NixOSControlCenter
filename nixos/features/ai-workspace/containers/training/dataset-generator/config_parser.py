def parse_nixos_config(config_path):
    datasets = []
    
    # Config-Dateien finden
    config_files = find_nix_files(config_path)
    
    for file in config_files:
        # Parse Nix-File
        content = parse_nix_file(file)
        
        # Generiere Datasets
        datasets.extend([
            {
                "instruction": f"Create a NixOS configuration for {content.purpose}",
                "response": generate_minimal_config(content)
            },
            {
                "instruction": f"Explain this NixOS configuration:\n```nix\n{content.code}\n```",
                "response": generate_explanation(content)
            }
        ])
    
    return datasets