#!/usr/bin/env python3
import json
import requests
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime

class NixOSExplanationDataset:
    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Documentation references
        self.docs = {
            "manual": "https://nixos.org/manual/nixos/stable/",
            "nix_manual": "https://nixos.org/manual/nix/stable/",
            "wiki": "https://nixos.wiki/",
            "discourse": "https://discourse.nixos.org/"
        }
        
    def fetch_latest_nixpkgs_version(self) -> str:
        """Fetch the latest NixOS version from GitHub."""
        try:
            response = requests.get("https://api.github.com/repos/NixOS/nixpkgs/releases/latest")
            return response.json()["tag_name"]
        except:
            return "23.11"  # Fallback version
        
    def generate_concept_dataset(self) -> None:
        """Generate dataset explaining core NixOS concepts."""
        concepts = [
            {
                "concept": "NixOS vs Traditional Linux",
                "explanation": """
                NixOS is not just another Linux distribution - it's a fundamentally different approach to system configuration:
                
                1. Traditional Linux:
                   - Uses imperative package management (apt, yum)
                   - System state changes over time
                   - Configuration spread across /etc
                   - Package dependencies can conflict
                
                2. NixOS:
                   - Purely declarative configuration
                   - Atomic system updates
                   - Single configuration.nix
                   - Guaranteed reproducibility
                   - No dependency conflicts
                   - Can roll back any change
                """,
                "key_differences": [
                    "Package management approach",
                    "System state handling",
                    "Configuration management",
                    "Dependency resolution"
                ]
            },
            {
                "concept": "Nix Package Manager",
                "explanation": """
                Nix is the package manager that powers NixOS:
                
                1. Key Features:
                   - Pure functional package management
                   - Each package in isolated directory
                   - Multiple versions can coexist
                   - Garbage collection of unused packages
                
                2. Benefits:
                   - Reproducible builds
                   - Atomic upgrades/rollbacks
                   - No dependency hell
                   - Development environments
                """,
                "use_cases": [
                    "System package management",
                    "Development environments",
                    "Application deployment",
                    "Build systems"
                ]
            },
            {
                "concept": "Nix Language",
                "explanation": """
                The Nix language is a pure, lazy, functional language:
                
                1. Characteristics:
                   - Purely functional
                   - Lazy evaluation
                   - No side effects
                   - Declarative syntax
                
                2. Key Concepts:
                   - Attributes sets
                   - Functions
                   - Derivations
                   - Import system
                """,
                "examples": [
                    "{ config, pkgs, ... }: { ... }",
                    "pkgs.mkDerivation { ... }",
                    "import <nixpkgs> {}"
                ]
            },
            {
                "concept": "NixOS System Architecture",
                "explanation": """
                NixOS architecture is built around reproducibility:
                
                1. Core Components:
                   - Nix store (/nix/store)
                   - System profile
                   - Boot loader configuration
                   - Systemd services
                
                2. Key Features:
                   - Atomic updates
                   - Multiple configurations
                   - Service management
                   - Hardware detection
                """,
                "components": [
                    "/nix/store",
                    "/etc/nixos",
                    "/run/current-system",
                    "/boot"
                ]
            },
            {
                "concept": "Declarative Configuration",
                "explanation": """
                NixOS uses a declarative approach to system configuration:
                
                1. Benefits:
                   - System state is predictable
                   - Configuration is reproducible
                   - Easy to version control
                   - Self-documenting
                
                2. How it works:
                   - Define desired state in configuration.nix
                   - NixOS calculates required changes
                   - System updated atomically
                   - Previous state preserved
                """,
                "examples": [
                    "services.nginx.enable = true;",
                    "users.users.alice.isNormalUser = true;",
                    "networking.hostName = \"myhost\";"
                ]
            },
            {
                "concept": "NixOS Modules",
                "explanation": """
                NixOS uses a modular system for configuration:
                
                1. Module System:
                   - Composable configurations
                   - Option declarations
                   - Implementation logic
                   - Import system
                
                2. Types of Modules:
                   - System modules
                   - Service modules
                   - User modules
                   - Hardware modules
                """,
                "examples": [
                    "./hardware-configuration.nix",
                    "./desktop-environment.nix",
                    "<nixos-hardware/dell/xps/15-9500>"
                ]
            },
            {
                "concept": "NixOS Development Environments",
                "explanation": """
                NixOS provides powerful development environment management:
                
                1. nix-shell:
                   - Isolated development environments
                   - Project-specific dependencies
                   - Reproducible across machines
                   - Shell.nix configuration
                
                2. devShell (Flakes):
                   - Modern development environments
                   - Declarative shell environments
                   - Better integration with IDEs
                   - Faster activation
                
                3. direnv integration:
                   - Automatic environment activation
                   - Project-specific environment variables
                   - Layout-based configuration
                   - Shell history isolation
                """,
                "examples": [
                    "nix-shell -p python3 poetry",
                    "{ pkgs ? import <nixpkgs> {} }: pkgs.mkShell { buildInputs = [ pkgs.python3 ]; }",
                    "use flake"
                ],
                "documentation": "${self.docs['manual']}#sec-nix-shell"
            },
            {
                "concept": "NixOS Container Management",
                "explanation": """
                NixOS offers native container support and Docker integration:
                
                1. NixOS Containers:
                   - Lightweight system containers
                   - Declarative configuration
                   - Shared Nix store
                   - Resource isolation
                
                2. Docker Integration:
                   - Build reproducible images
                   - Multi-stage builds
                   - Layer deduplication
                   - Development containers
                """,
                "examples": [
                    "containers.mycontainer = { config = { ... }; };",
                    "dockerTools.buildImage { name = \"myapp\"; tag = \"latest\"; }",
                ],
                "documentation": "${self.docs['manual']}#ch-containers"
            },
            {
                "concept": "NixOS Testing Framework",
                "explanation": """
                NixOS includes a powerful system testing framework:
                
                1. Test Types:
                   - Unit tests
                   - Integration tests
                   - System tests
                   - VM tests
                
                2. Features:
                   - Declarative test definitions
                   - Automated VM creation
                   - Network simulation
                   - Service testing
                """,
                "examples": [
                    "nixosTest { testScript = '''python code'''; }",
                    "virtualisation.memorySize = 2048;",
                ],
                "documentation": "${self.docs['manual']}#sec-nixos-tests"
            }
        ]
        
        advanced_concepts = [
            {
                "concept": "NixOS Overlays",
                "explanation": """
                Overlays provide a way to customize package sets:
                
                1. Purpose:
                   - Modify existing packages
                   - Add new packages
                   - Override dependencies
                   - Layer modifications
                
                2. Types:
                   - User overlays
                   - System overlays
                   - Flake overlays
                   - Channel overlays
                """,
                "examples": [
                    "self: super: { package = super.package.override { }; }",
                    "nixpkgs.overlays = [ (import ./overlay.nix) ];",
                ],
                "documentation": "${self.docs['manual']}#sec-overlays"
            },
            {
                "concept": "NixOS Module System Internals",
                "explanation": """
                Deep dive into the NixOS module system:
                
                1. Module Structure:
                   - Options declaration
                   - Implementation
                   - Dependencies
                   - Assertions
                
                2. Advanced Features:
                   - Module composition
                   - Option types
                   - Submodules
                   - Conditionals
                """,
                "examples": [
                    "options.services.myservice = mkOption { type = types.submodule { ... }; };",
                    "config = mkIf cfg.enable { ... };",
                ],
                "documentation": "${self.docs['manual']}#sec-writing-modules"
            },
            {
                "concept": "Nix Derivations",
                "explanation": """
                Derivations are the building blocks of the Nix system:
                
                1. What are Derivations:
                   - Build instructions
                   - Input dependencies
                   - Build environment
                   - Output paths
                
                2. How they work:
                   - Pure functions
                   - Deterministic builds
                   - Cached results
                   - Content-addressed storage
                """,
                "examples": [
                    "stdenv.mkDerivation { ... }",
                    "pkgs.writeText \"name\" \"content\"",
                    "pkgs.runCommand \"name\" { } \"command\""
                ]
            },
            {
                "concept": "NixOS Generations",
                "explanation": """
                NixOS maintains system generations for reliability:
                
                1. What are Generations:
                   - Complete system snapshots
                   - Bootable configurations
                   - Atomic updates
                   - Rollback targets
                
                2. Benefits:
                   - Safe updates
                   - Easy rollbacks
                   - Testing new configs
                   - System reliability
                """,
                "commands": [
                    "nixos-rebuild switch",
                    "nixos-rebuild boot",
                    "nixos-rebuild test"
                ]
            }
        ]
        
        training_tasks = [
            {
                "task": "explain_nixos_benefits",
                "input": "What are the main benefits of using NixOS compared to traditional Linux distributions?",
                "output": """
                NixOS offers several key benefits over traditional Linux distributions:
                1. Reproducible system configurations through declarative configuration
                2. Atomic system updates and rollbacks
                3. No dependency conflicts due to isolated package storage
                4. Multiple versions of packages can coexist
                5. Complete system state defined in configuration files
                6. Development environments that don't pollute the system
                """
            },
            {
                "task": "explain_nix_store",
                "input": "How does the Nix store work and why is it important?",
                "output": """
                The Nix store (/nix/store) is fundamental to NixOS:
                1. Each package has a unique hash-based path
                2. Packages are immutable once installed
                3. Multiple versions can coexist
                4. Dependencies are explicitly declared
                5. Unused packages can be garbage collected
                6. Enables atomic updates and rollbacks
                """
            },
            {
                "task": "explain_flakes",
                "input": "What are Nix flakes and why should I use them?",
                "output": """
                Nix flakes are a modern approach to Nix package management:
                1. Reproducible dependencies through flake.lock
                2. Standardized project structure
                3. Better composability of Nix code
                4. Improved CLI interface
                5. Built-in version control support
                6. Hermetic evaluation
                """
            },
            {
                "task": "create_development_environment",
                "input": "How do I create a Python development environment with Poetry in NixOS?",
                "output": """
                Here's how to create a Python development environment with Poetry:
                
                1. Create shell.nix:
                ```nix
                { pkgs ? import <nixpkgs> {} }:
                pkgs.mkShell {
                  buildInputs = with pkgs; [
                    python3
                    python3Packages.pip
                    python3Packages.virtualenv
                    poetry
                  ];
                  shellHook = ''
                    export PIP_PREFIX=$(pwd)/_build/pip_packages
                    export PYTHONPATH="$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
                    export PATH="$PIP_PREFIX/bin:$PATH"
                    if [ ! -d $PIP_PREFIX ]; then
                      mkdir -p $PIP_PREFIX
                    fi
                  '';
                }
                ```
                
                2. Or using flake.nix:
                ```nix
                {
                  description = "Python development environment";
                  inputs = {
                    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
                    flake-utils.url = "github:numtide/flake-utils";
                  };
                  outputs = { self, nixpkgs, flake-utils }:
                    flake-utils.lib.eachDefaultSystem (system:
                      let
                        pkgs = nixpkgs.legacyPackages.\${system};
                      in {
                        devShell = pkgs.mkShell {
                          buildInputs = with pkgs; [ python3 poetry ];
                        };
                      }
                    );
                }
                """
            },
            {
                "task": "debug_nixos_system",
                "input": "How do I debug NixOS system issues and configuration problems?",
                "output": """
                Here's a systematic approach to debug NixOS issues:
                
                1. Check System Logs:
                   - journalctl -xe
                   - systemctl status service-name
                   - nixos-rebuild build --show-trace
                
                2. Test Configuration:
                   - nixos-rebuild test
                   - nix-instantiate --eval
                   - nix repl
                
                3. Common Debug Tools:
                   - nix why-depends
                   - nix-store --verify
                   - nix-store --repair
                
                4. Configuration Validation:
                   - Check syntax with nix-instantiate
                   - Validate paths and imports
                   - Check option values
                """
            },
            {
                "task": "optimize_nixos_system",
                "input": "How can I optimize my NixOS system for better performance and disk usage?",
                "output": """
                Here are key optimization strategies for NixOS:
                
                1. Nix Store Optimization:
                   - nix-collect-garbage -d
                   - nix optimise-store
                   - Remove old generations
                
                2. System Configuration:
                   - Use binary caches
                   - Enable compression
                   - Configure automatic cleanup
                
                3. Performance Tuning:
                   - services.nix-daemon.settings = {
                       cores = 0;  # Use all cores
                       max-jobs = "auto";
                   };
                   - boot.tmp.cleanOnBoot = true;
                   - nix.settings.auto-optimise-store = true;
                
                4. Development Optimization:
                   - Use direnv
                   - Enable flake support
                   - Configure binary substituters
                """
            }
        ]
        
        # Add practical examples and common patterns
        practical_examples = [
            {
                "category": "System Management",
                "examples": [
                    {
                        "title": "System Update",
                        "description": "Different ways to update NixOS system",
                        "commands": [
                            "nixos-rebuild switch --upgrade",
                            "nix flake update",
                            "nix-channel --update nixos"
                        ],
                        "explanation": """
                        1. Traditional Channel Update:
                           - nix-channel --update nixos
                           - nixos-rebuild switch
                        
                        2. Flake-based Update:
                           - nix flake update
                           - nixos-rebuild switch --flake .#
                        
                        3. Direct Upgrade:
                           - nixos-rebuild switch --upgrade
                        """
                    },
                    {
                        "title": "Package Management",
                        "description": "Common package management tasks",
                        "examples": [
                            "nix-env -iA nixos.firefox",
                            "nix shell nixpkgs#python3",
                            "nix profile install nixpkgs#vscode"
                        ],
                        "explanation": """
                        1. Traditional Installation:
                           - nix-env -iA nixos.package
                           - nix-env -e package
                        
                        2. Modern Approaches:
                           - nix profile install
                           - nix shell
                           - home-manager
                        """
                    }
                ]
            },
            {
                "category": "Development Workflows",
                "examples": [
                    {
                        "title": "Python Development",
                        "description": "Setting up Python development environment",
                        "files": {
                            "shell.nix": """
                            { pkgs ? import <nixpkgs> {} }:
                            pkgs.mkShell {
                              buildInputs = with pkgs; [
                                python3
                                python3Packages.pip
                                python3Packages.virtualenv
                                poetry
                              ];
                              shellHook = ''
                                export PIP_PREFIX=$(pwd)/_build/pip_packages
                                export PYTHONPATH="$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
                                export PATH="$PIP_PREFIX/bin:$PATH"
                                if [ ! -d $PIP_PREFIX ]; then
                                  mkdir -p $PIP_PREFIX
                                fi
                              '';
                            }
                            """,
                            "flake.nix": """
                            {
                              description = "Python development environment";
                              inputs = {
                                nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
                                flake-utils.url = "github:numtide/flake-utils";
                              };
                              outputs = { self, nixpkgs, flake-utils }:
                                flake-utils.lib.eachDefaultSystem (system:
                                  let
                                    pkgs = nixpkgs.legacyPackages.\${system};
                                  in {
                                    devShell = pkgs.mkShell {
                                      buildInputs = with pkgs; [ python3 poetry ];
                                    };
                                  }
                                );
                            }
                            """
                        }
                    },
                    {
                        "title": "Web Development",
                        "description": "Setting up Node.js development environment",
                        "files": {
                            "shell.nix": """
                            { pkgs ? import <nixpkgs> {} }:
                            pkgs.mkShell {
                              buildInputs = with pkgs; [
                                nodejs_20
                                yarn
                                nodePackages.pnpm
                              ];
                              shellHook = ''
                                export PATH="$PWD/node_modules/.bin:$PATH"
                              '';
                            }
                            """
                        }
                    }
                ]
            },
            {
                "category": "System Configuration",
                "examples": [
                    {
                        "title": "Desktop Environment",
                        "description": "Setting up KDE Plasma with customizations",
                        "configuration": """
                        { config, pkgs, ... }:
                        {
                          services.xserver = {
                            enable = true;
                            displayManager.sddm.enable = true;
                            desktopManager.plasma5.enable = true;
                          };
                          
                          environment.systemPackages = with pkgs; [
                            kate
                            konsole
                            plasma-browser-integration
                          ];
                          
                          programs.kde = {
                            enable = true;
                            applications = {
                              kate.enable = true;
                              konsole.enable = true;
                            };
                          };
                        }
                        """
                    },
                    {
                        "title": "Development Server",
                        "description": "Setting up a development server with common tools",
                        "configuration": """
                        { config, pkgs, ... }:
                        {
                          services = {
                            postgresql = {
                              enable = true;
                              package = pkgs.postgresql_14;
                              enableTCPIP = true;
                              authentication = pkgs.lib.mkOverride 10 ''
                                local all all trust
                                host all all 127.0.0.1/32 trust
                              '';
                            };
                            
                            redis.servers."main" = {
                              enable = true;
                              port = 6379;
                            };
                            
                            nginx = {
                              enable = true;
                              recommendedProxySettings = true;
                              recommendedTlsSettings = true;
                            };
                          };
                          
                          networking.firewall.allowedTCPPorts = [ 80 443 5432 6379 ];
                        }
                        """
                    }
                ]
            }
        ]
        
        # Add troubleshooting guides
        troubleshooting_guides = [
            {
                "issue": "System Won't Boot After Update",
                "steps": [
                    "1. Boot into previous generation using GRUB/systemd-boot menu",
                    "2. Check system logs: journalctl -xb",
                    "3. Rebuild with show-trace: nixos-rebuild switch --show-trace",
                    "4. Check configuration.nix for errors",
                    "5. Rollback if needed: nixos-rebuild switch --rollback"
                ],
                "common_causes": [
                    "Incorrect hardware configuration",
                    "Broken package dependencies",
                    "Syntax errors in configuration",
                    "Missing kernel modules"
                ]
            },
            {
                "issue": "Package Build Failures",
                "steps": [
                    "1. Check build logs: nix log /nix/store/hash",
                    "2. Verify dependencies: nix why-depends",
                    "3. Try building in isolation: nix-build -K",
                    "4. Check for upstream issues",
                    "5. Use alternative package version"
                ],
                "common_causes": [
                    "Missing build dependencies",
                    "Incompatible compiler versions",
                    "Network issues during fetch",
                    "Disk space issues"
                ]
            }
        ]
        
        # Save datasets with version info
        metadata = {
            "version": self.fetch_latest_nixpkgs_version(),
            "generated_at": datetime.now().isoformat(),
            "documentation_sources": self.docs
        }
        
        self._save_dataset('nixos_concepts.jsonl', concepts)
        self._save_dataset('nixos_advanced_concepts.jsonl', advanced_concepts)
        self._save_dataset('nixos_training_tasks.jsonl', training_tasks)
        self._save_dataset('nixos_dataset_metadata.json', [metadata])
        self._save_dataset('nixos_practical_examples.jsonl', practical_examples)
        self._save_dataset('nixos_troubleshooting.jsonl', troubleshooting_guides)

    def _save_dataset(self, filename: str, data: List[Dict[str, Any]]) -> None:
        """Save dataset to a JSONL file."""
        output_file = self.output_dir / filename
        with open(output_file, 'w') as f:
            for item in data:
                f.write(json.dumps(item) + '\n')

def main():
    generator = NixOSExplanationDataset('/home/fr4iser/Documents/Git/NixOsControlCenter/datasets')
    generator.generate_concept_dataset()
    print("NixOS explanation dataset generated successfully!")

if __name__ == "__main__":
    main()