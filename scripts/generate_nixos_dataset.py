#!/usr/bin/env python3
import os
import json
import random
from pathlib import Path
import yaml
from typing import Dict, List, Any, Union
import itertools

class NixOSDatasetGenerator:
    def __init__(self, config_dir: str):
        self.config_dir = Path(config_dir)
        self.system_config = self.config_dir / "system-config.nix"
        self.output_dir = self.config_dir / "datasets"
        self.output_dir.mkdir(exist_ok=True)
        
        # Common Nix expressions and patterns
        self.nix_patterns = {
            'nixpkgs_import': 'import <nixpkgs> {}',
            'flake_inputs': [
                'nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"',
                'nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"',
                'home-manager.url = "github:nix-community/home-manager"',
                'home-manager.inputs.nixpkgs.follows = "nixpkgs"',
                'nixos-hardware.url = "github:NixOS/nixos-hardware"'
            ],
            'common_imports': [
                './hardware-configuration.nix',
                '<home-manager/nixos>',
                '<nixos-hardware/common/cpu/intel>',
                '<nixos-hardware/common/gpu/nvidia>',
                './modules/desktop.nix',
                './modules/development.nix',
                './modules/gaming.nix'
            ]
        }
        
        # Common nixpkgs patterns
        self.nixpkgs_patterns = {
            'overlays': [
                '[(self: super: { })]',
                '[(import ./overlays/custom.nix)]',
                '[(self: super: { myapp = super.callPackage ./pkgs/myapp { }; })]'
            ],
            'config': [
                '{ allowUnfree = true; }',
                '{ allowUnfree = true; allowBroken = true; }',
                '{ allowUnfree = true; permittedInsecurePackages = [ "openssl-1.1.1u" ]; }'
            ]
        }

    def generate_flake_nix(self) -> Dict[str, Any]:
        """Generate a flake.nix configuration."""
        inputs = {
            'nixpkgs': {'url': random.choice([
                'github:NixOS/nixpkgs/nixos-unstable',
                'github:NixOS/nixpkgs/nixos-23.11',
                'github:NixOS/nixpkgs/master'
            ])},
            'home-manager': {
                'url': 'github:nix-community/home-manager',
                'inputs': {'nixpkgs': {'follows': 'nixpkgs'}}
            }
        }
        
        # Add optional inputs
        if random.choice([True, False]):
            inputs['nixos-hardware'] = {'url': 'github:NixOS/nixos-hardware'}
        if random.choice([True, False]):
            inputs['nix-colors'] = {'url': 'github:misterio77/nix-colors'}
        
        return {
            'description': 'NixOS system configuration',
            'inputs': inputs,
            'outputs': '{ nixpkgs, home-manager, ... }@inputs: {'
                      '  nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {'
                      '    system = "x86_64-linux";'
                      '    modules = [ ./configuration.nix'
                      '               home-manager.nixosModules.home-manager ];'
                      '  };'
                      '}'
        }

    def generate_nix_module(self, module_type: str) -> Dict[str, Any]:
        """Generate a Nix module configuration."""
        module = {
            'imports': random.sample(self.nix_patterns['common_imports'], 
                                  k=random.randint(1, 3)),
            'options': {},
            'config': {}
        }
        
        if module_type == 'desktop':
            module['options'] = {
                'myconfig.desktop.enable': {
                    'type': 'bool',
                    'default': 'false',
                    'description': 'Enable desktop configuration'
                }
            }
            module['config'] = {
                'services.xserver.enable': 'true',
                'services.xserver.displayManager.sddm.enable': 'true',
                'services.xserver.desktopManager.plasma5.enable': 'true'
            }
        elif module_type == 'development':
            module['config'] = {
                'environment.systemPackages': [
                    'git', 'vim', 'vscode', 'docker'
                ]
            }
        
        return module

    def parse_nix_config(self, content: str) -> Dict[str, Any]:
        """Parse simplified Nix configuration into Python dictionary."""
        # Remove comments and empty lines
        lines = [line.strip() for line in content.split('\n') 
                if line.strip() and not line.strip().startswith('#')]
        
        config_dict = {}
        current_section = config_dict
        section_stack = []
        
        for line in lines:
            if '{' in line:
                section_name = line.split('{')[0].strip().strip('=').strip()
                if section_name:
                    current_section[section_name] = {}
                    section_stack.append(current_section)
                    current_section = current_section[section_name]
            elif '}' in line and section_stack:
                current_section = section_stack.pop()
            elif '=' in line:
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip().strip(';').strip('"')
                if value.lower() == 'true':
                    value = True
                elif value.lower() == 'false':
                    value = False
                current_section[key] = value
                
        return config_dict

    def generate_variations(self, config: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate meaningful variations of the configuration."""
        variations = []
        
        # Extended configuration options
        system_types = ['desktop', 'server', 'laptop', 'workstation', 'vm', 'container']
        desktop_environments = ['plasma', 'gnome', 'xfce', 'i3', 'sway', 'mate', 'cinnamon', 'enlightenment']
        display_managers = ['sddm', 'gdm', 'lightdm', 'ly']
        display_servers = ['wayland', 'x11']
        shells = ['zsh', 'bash', 'fish', 'nushell']
        cpu_types = ['intel', 'amd', 'arm']
        gpu_types = ['nvidia', 'amd', 'intel', 'none']
        memory_sizes = [4, 8, 16, 32, 64, 128]
        user_roles = ['admin', 'user', 'developer', 'guest']
        
        # Generate base variations
        for sys_type in system_types:
            # Create multiple variations for each system type
            for _ in range(5):  # Generate 5 variations per system type
                base_variation = config.copy()
                base_variation['systemType'] = sys_type
                base_variation['system'] = {
                    'channel': random.choice(['stable', 'unstable', 'testing']),
                    'version': random.choice(['23.11', '24.05', '24.11']),
                    'bootloader': random.choice(['systemd-boot', 'grub', 'refind'])
                }
                
                # Hardware configuration
                base_variation['hardware'] = {
                    'cpu': random.choice(cpu_types),
                    'gpu': random.choice(gpu_types),
                    'memory': {'sizeGB': random.choice(memory_sizes)}
                }
                
                # User configuration
                num_users = random.randint(1, 4)
                users = {}
                for i in range(num_users):
                    username = f"user{i+1}"
                    users[username] = {
                        'role': random.choice(user_roles),
                        'defaultShell': random.choice(shells),
                        'autoLogin': random.choice([True, False])
                    }
                base_variation['users'] = users
                
                # Desktop configuration for appropriate system types
                if sys_type in ['desktop', 'laptop', 'workstation']:
                    de = random.choice(desktop_environments)
                    base_variation['desktop'] = {
                        'enable': True,
                        'environment': de,
                        'display': {
                            'manager': random.choice(display_managers),
                            'server': random.choice(display_servers),
                            'session': de
                        },
                        'theme': {
                            'dark': random.choice([True, False])
                        },
                        'audio': random.choice(['pipewire', 'pulseaudio'])
                    }
                
                # Package modules configuration
                base_variation['packageModules'] = {
                    'gaming': {
                        'streaming': random.choice([True, False]),
                        'emulation': random.choice([True, False])
                    },
                    'development': {
                        'game': random.choice([True, False]),
                        'web': random.choice([True, False]),
                        'mobile': random.choice([True, False]),
                        'data': random.choice([True, False])
                    },
                    'server': {
                        'docker': random.choice([True, False]),
                        'web': random.choice([True, False]),
                        'database': random.choice([True, False])
                    }
                }
                
                # Features configuration
                features = [
                    'system-logger', 'system-checks', 'system-updater',
                    'system-config-manager', 'ssh-client-manager', 'ssh-server-manager',
                    'bootentry-manager', 'container-manager', 'homelab-manager',
                    'vm-manager', 'ai-workspace'
                ]
                base_variation['features'] = {
                    feature: random.choice([True, False])
                    for feature in features
                }
                
                variations.append(base_variation)
        
        return variations

    def generate_dataset(self) -> None:
        """Generate training dataset from NixOS configurations."""
        with open(self.system_config, 'r') as f:
            content = f.read()
        
        base_config = self.parse_nix_config(content)
        variations = self.generate_variations(base_config)
        
        # Generate different dataset formats
        self._save_json_dataset(variations)
        self._save_yaml_dataset(variations)
        self._save_transformer_dataset(variations)
        
        # Generate additional Nix-specific examples
        self._generate_nix_examples()

    def _save_json_dataset(self, variations: List[Dict[str, Any]]) -> None:
        """Save dataset in JSON format."""
        output_file = self.output_dir / 'nixos_configs.json'
        with open(output_file, 'w') as f:
            json.dump(variations, f, indent=2)
    
    def _save_yaml_dataset(self, variations: List[Dict[str, Any]]) -> None:
        """Save dataset in YAML format."""
        output_file = self.output_dir / 'nixos_configs.yaml'
        with open(output_file, 'w') as f:
            yaml.dump(variations, f)
    
    def _save_transformer_dataset(self, variations: List[Dict[str, Any]]) -> None:
        """Save dataset in a format suitable for transformer training."""
        output_file = self.output_dir / 'nixos_configs_transformer.jsonl'
        
        with open(output_file, 'w') as f:
            for config in variations:
                # Generate Nix-specific configurations
                flake_config = self.generate_flake_nix()
                desktop_module = self.generate_nix_module('desktop')
                
                # Create multiple types of training tasks
                tasks = [
                    {
                        "task": "config_generation",
                        "input": f"Generate a NixOS configuration for a {config['systemType']} system with {config['hardware']['cpu']} CPU and {config['hardware']['gpu']} GPU",
                        "output": json.dumps(config)
                    },
                    {
                        "task": "flake_generation",
                        "input": "Generate a flake.nix for a NixOS system with home-manager and hardware configuration",
                        "output": json.dumps(flake_config)
                    },
                    {
                        "task": "module_generation",
                        "input": "Create a NixOS module for desktop environment configuration",
                        "output": json.dumps(desktop_module)
                    },
                    {
                        "task": "nixpkgs_overlay",
                        "input": "Create a nixpkgs overlay to customize package builds",
                        "output": random.choice(self.nixpkgs_patterns['overlays'])
                    },
                    {
                        "task": "import_explanation",
                        "input": "Explain how to import nixpkgs and use it in a configuration",
                        "output": "To import nixpkgs, you can use either:\n"
                                "1. `import <nixpkgs> {}` in traditional configs\n"
                                "2. Use flake inputs: `inputs.nixpkgs.legacyPackages.\${system}`\n"
                                "3. Or in configuration.nix: `{ pkgs, ... }:`"
                    },
                    {
                        "task": "flake_concept",
                        "input": "Explain what a Nix flake is and its benefits",
                        "output": "A Nix flake is a source tree with a flake.nix that provides a standardized interface to Nix artifacts like packages or NixOS configurations. Benefits include:\n"
                                "1. Reproducible dependencies via flake.lock\n"
                                "2. Standardized CLI interface\n"
                                "3. Better composability of Nix code\n"
                                "4. Built-in support for version control"
                    }
                ]
                
                for task in tasks:
                    f.write(json.dumps(task) + '\n')

    def _generate_nix_examples(self) -> None:
        """Generate additional Nix-specific example configurations."""
        output_file = self.output_dir / 'nixos_examples.jsonl'
        
        examples = [
            {
                "type": "declarative_concept",
                "title": "NixOS Declarative Configuration",
                "explanation": "NixOS uses a declarative approach where you specify the desired system state rather than steps to achieve it. Benefits include:\n"
                             "1. Reproducibility: Same config = Same result\n"
                             "2. Atomic upgrades and rollbacks\n"
                             "3. No system state mutations during package management\n"
                             "4. Conflict-free package management"
            },
            {
                "type": "nixpkgs_concept",
                "title": "Understanding nixpkgs",
                "explanation": "nixpkgs is the main package collection for Nix/NixOS containing:\n"
                             "1. Package definitions\n"
                             "2. NixOS modules\n"
                             "3. Functions and libraries for package building\n"
                             "Access via: import <nixpkgs> {} or through flake inputs"
            },
            {
                "type": "module_system",
                "title": "NixOS Module System",
                "explanation": "NixOS uses a modular configuration system where:\n"
                             "1. Modules declare options and implementations\n"
                             "2. Options have types, descriptions, and defaults\n"
                             "3. Modules can be composed and override each other\n"
                             "4. Configuration is merged automatically"
            }
        ]
        
        with open(output_file, 'w') as f:
            for example in examples:
                f.write(json.dumps(example) + '\n')

    def _generate_config_analysis(self, config: Dict[str, Any]) -> str:
        """Generate a detailed analysis of the configuration."""
        analysis = []
        analysis.append(f"This is a {config['systemType']} system running NixOS {config['system']['version']}")
        
        if 'desktop' in config and config['desktop']['enable']:
            analysis.append(f"using {config['desktop']['environment']} desktop environment")
        
        analysis.append(f"with {config['hardware']['cpu']} CPU, {config['hardware']['gpu']} GPU, and {config['hardware']['memory']['sizeGB']}GB of RAM")
        
        enabled_features = [f for f, enabled in config['features'].items() if enabled]
        if enabled_features:
            analysis.append(f"Enabled features: {', '.join(enabled_features)}")
        
        return ' '.join(analysis)
    
    def _get_system_purpose(self, config: Dict[str, Any]) -> str:
        """Determine the primary purpose of the system based on configuration."""
        purposes = []
        
        if config['packageModules']['gaming']['streaming'] or config['packageModules']['gaming']['emulation']:
            purposes.append('gaming')
        
        if any(config['packageModules']['development'].values()):
            purposes.append('development')
            
        if any(config['packageModules']['server'].values()):
            purposes.append('server')
            
        return ' and '.join(purposes) if purposes else 'general purpose'

def main():
    generator = NixOSDatasetGenerator('/home/fr4iser/Documents/Git/NixOsControlCenter/nixos')
    generator.generate_dataset()
    print("Dataset generation complete! Check the 'datasets' directory for the generated files.")

if __name__ == "__main__":
    main()
