# Development Setup

## Overview

This guide will help you set up a development environment for contributing to NixOSControlCenter. It covers everything from initial setup to advanced development workflows.

## Prerequisites

### System Requirements
- **Operating System**: NixOS (recommended) or Linux with Nix
- **RAM**: Minimum 8GB, recommended 16GB+
- **Storage**: Minimum 20GB free space
- **Network**: Stable internet connection

### Required Software
- **Nix Package Manager**: Latest version
- **Git**: For version control
- **Editor**: VS Code, Vim, or your preferred editor
- **Terminal**: Modern terminal with good Unicode support

## Initial Setup

### 1. Clone the Repository
```bash
# Clone the main repository
git clone https://github.com/fr4iser90/NixOSControlCenter.git
cd NixOSControlCenter

# Add upstream remote (if forking)
git remote add upstream https://github.com/fr4iser90/NixOSControlCenter.git
```

### 2. Set Up Development Environment
```bash
# Enter development shell
nix-shell

# Or use direnv (if configured)
direnv allow
```

### 3. Install Development Dependencies
```bash
# Install development tools
nixos-control-center dev setup

# Install additional development packages
nixos-control-center dev packages install

# Verify installation
nixos-control-center dev verify
```

## Development Environment Configuration

### Editor Setup

#### VS Code Configuration
```json
// .vscode/settings.json
{
  "nix.enableLanguageServer": true,
  "nix.serverPath": "nixd",
  "files.associations": {
    "*.nix": "nix"
  },
  "editor.formatOnSave": true,
  "editor.rulers": [80, 100],
  "files.trimTrailingWhitespace": true
}
```

#### Vim/Neovim Configuration
```vim
" .vimrc or init.vim
" Nix syntax highlighting
autocmd BufRead,BufNewFile *.nix set filetype=nix

" Language server
if executable('nixd')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'nixd',
    \ 'cmd': {server_info->['nixd']},
    \ 'whitelist': ['nix'],
    \ })
endif
```

### Shell Configuration

#### Bash Configuration
```bash
# ~/.bashrc or ~/.bash_profile
export NIXOS_CONTROL_CENTER_DEV=1
export NIXOS_CONTROL_CENTER_LOG_LEVEL=debug

# Development aliases
alias ncc-dev="nixos-control-center --dev"
alias ncc-test="nixos-control-center test"
alias ncc-build="nixos-control-center build"
```

#### Fish Configuration
```fish
# ~/.config/fish/config.fish
set -gx NIXOS_CONTROL_CENTER_DEV 1
set -gx NIXOS_CONTROL_CENTER_LOG_LEVEL debug

# Development aliases
alias ncc-dev="nixos-control-center --dev"
alias ncc-test="nixos-control-center test"
alias ncc-build="nixos-control-center build"
```

## Project Structure

### Understanding the Codebase
```
NixOSControlCenter/
├── nixos/                    # NixOS configurations
│   ├── core/                # Core system functionality
│   ├── features/            # Feature modules
│   ├── desktop/             # Desktop environment configs
│   └── packages/            # Package definitions
├── shell/                   # Shell scripts and tools
│   ├── scripts/             # Main scripts
│   ├── packages/            # Shell package definitions
│   └── hooks/               # Shell hooks
├── docs/                    # Documentation
├── tests/                   # Test suite
├── examples/                # Example configurations
└── flake.nix               # Nix flake definition
```

### Key Development Files
- `flake.nix`: Main flake definition
- `shell.nix`: Development shell configuration
- `default.nix`: Default package configuration
- `nixos/modules/default.nix`: Module definitions
- `shell/scripts/`: Main script implementations

## Development Workflow

### 1. Feature Development

#### Create Feature Branch
```bash
# Create and switch to feature branch
git checkout -b feature/your-feature-name

# Or use the development helper
nixos-control-center dev branch create feature/your-feature-name
```

#### Development Cycle
```bash
# Make changes to code
# Test changes
nixos-control-center dev test

# Build changes
nixos-control-center dev build

# Run linting
nixos-control-center dev lint

# Format code
nixos-control-center dev format
```

#### Commit Changes
```bash
# Stage changes
git add .

# Commit with conventional commit message
git commit -m "feat: add new feature description"

# Push to remote
git push origin feature/your-feature-name
```

### 2. Testing

#### Unit Tests
```bash
# Run all unit tests
nixos-control-center test unit

# Run specific test file
nixos-control-center test unit tests/unit/test-file.nix

# Run tests with coverage
nixos-control-center test unit --coverage
```

#### Integration Tests
```bash
# Run integration tests
nixos-control-center test integration

# Run specific integration test
nixos-control-center test integration tests/integration/test-name

# Run tests in parallel
nixos-control-center test integration --parallel
```

#### End-to-End Tests
```bash
# Run E2E tests
nixos-control-center test e2e

# Run E2E tests with specific environment
nixos-control-center test e2e --env desktop

# Run E2E tests with debugging
nixos-control-center test e2e --debug
```

### 3. Building

#### Local Build
```bash
# Build the project
nixos-control-center dev build

# Build specific component
nixos-control-center dev build --component system

# Build with optimizations
nixos-control-center dev build --optimize
```

#### Development Build
```bash
# Build for development
nixos-control-center dev build --dev

# Build with debugging symbols
nixos-control-center dev build --debug

# Build with profiling
nixos-control-center dev build --profile
```

### 4. Code Quality

#### Linting
```bash
# Run all linters
nixos-control-center dev lint

# Run specific linter
nixos-control-center dev lint --linter shellcheck

# Fix auto-fixable issues
nixos-control-center dev lint --fix
```

#### Formatting
```bash
# Format all code
nixos-control-center dev format

# Format specific files
nixos-control-center dev format --files "*.nix"

# Check formatting without changes
nixos-control-center dev format --check
```

#### Type Checking
```bash
# Run type checking
nixos-control-center dev typecheck

# Type check specific files
nixos-control-center dev typecheck --files "*.nix"

# Show type information
nixos-control-center dev typecheck --verbose
```

## Module Development

### Creating New Modules

#### Module Structure
```nix
# nixos/features/my-feature/default.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nixos-control-center.features.my-feature;
in {
  options.nixos-control-center.features.my-feature = {
    enable = mkEnableOption "My feature";
    
    setting = mkOption {
      type = types.str;
      default = "default-value";
      description = "Description of setting";
    };
  };

  config = mkIf cfg.enable {
    # Module implementation
    environment.systemPackages = with pkgs; [
      # Packages for this feature
    ];
    
    services.my-service = {
      enable = true;
      settings = {
        setting = cfg.setting;
      };
    };
  };
}
```

#### Module Testing
```nix
# tests/modules/my-feature.nix
{ pkgs, ... }:

{
  name = "my-feature-test";
  
  nodes.machine = { config, pkgs, ... }: {
    nixos-control-center.features.my-feature = {
      enable = true;
      setting = "test-value";
    };
  };

  testScript = ''
    machine.wait_for_unit("my-service")
    machine.succeed("systemctl is-active my-service")
  '';
}
```

### Script Development

#### Script Structure
```bash
#!/usr/bin/env bash
# shell/scripts/my-script.sh

set -euo pipefail

# Source common functions
source "${BASH_SOURCE%/*}/../lib/utils.sh"
source "${BASH_SOURCE%/*}/../lib/colors.sh"

# Script configuration
SCRIPT_NAME="my-script"
SCRIPT_VERSION="1.0.0"

# Help function
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] COMMAND

Commands:
    start    Start the service
    stop     Stop the service
    status   Show service status

Options:
    -h, --help      Show this help message
    -v, --version   Show version information
    -d, --debug     Enable debug mode
EOF
}

# Main function
main() {
    local command="${1:-}"
    
    case "$command" in
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        status)
            show_status
            ;;
        -h|--help)
            show_help
            ;;
        -v|--version)
            echo "$SCRIPT_NAME $SCRIPT_VERSION"
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
```

#### Script Testing
```bash
# tests/scripts/test-my-script.sh
#!/usr/bin/env bash

set -euo pipefail

# Test script functionality
test_start_command() {
    local output
    output=$(./shell/scripts/my-script.sh start 2>&1)
    assert_contains "$output" "Service started"
}

test_stop_command() {
    local output
    output=$(./shell/scripts/my-script.sh stop 2>&1)
    assert_contains "$output" "Service stopped"
}

test_help_command() {
    local output
    output=$(./shell/scripts/my-script.sh --help 2>&1)
    assert_contains "$output" "Usage:"
}

# Run tests
run_tests
```

## Debugging

### Debug Mode
```bash
# Enable debug mode
export NIXOS_CONTROL_CENTER_DEBUG=1

# Run with debug output
nixos-control-center --debug

# Debug specific component
nixos-control-center --debug --component system
```

### Logging
```bash
# Set log level
export NIXOS_CONTROL_CENTER_LOG_LEVEL=debug

# View debug logs
nixos-control-center logs --level debug

# Follow debug logs
nixos-control-center logs --level debug --follow
```

### Profiling
```bash
# Profile script execution
nixos-control-center dev profile --script my-script.sh

# Profile with flame graph
nixos-control-center dev profile --flamegraph

# Profile memory usage
nixos-control-center dev profile --memory
```

## Documentation

### Writing Documentation
```bash
# Generate documentation
nixos-control-center dev docs generate

# Serve documentation locally
nixos-control-center dev docs serve

# Validate documentation
nixos-control-center dev docs validate
```

### API Documentation
```bash
# Generate API documentation
nixos-control-center dev docs api

# Update API documentation
nixos-control-center dev docs api --update

# Validate API documentation
nixos-control-center dev docs api --validate
```

## Contributing

### Pull Request Process

#### Before Submitting
```bash
# Ensure all tests pass
nixos-control-center dev test

# Run full CI checks
nixos-control-center dev ci

# Update documentation
nixos-control-center dev docs update

# Format code
nixos-control-center dev format
```

#### Pull Request Checklist
- [ ] Tests pass locally
- [ ] Code is formatted
- [ ] Documentation is updated
- [ ] Commit messages follow conventions
- [ ] Branch is up to date with main

### Code Review

#### Review Guidelines
1. **Functionality**: Does the code work as intended?
2. **Performance**: Is the code efficient?
3. **Security**: Are there security implications?
4. **Maintainability**: Is the code maintainable?
5. **Documentation**: Is the code well-documented?

#### Review Process
```bash
# Review specific files
nixos-control-center dev review --files "*.nix"

# Review with automated checks
nixos-control-center dev review --auto

# Generate review report
nixos-control-center dev review --report
```

## Advanced Development

### Custom Development Environment

#### Custom Shell Configuration
```nix
# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Development tools
    nixd
    shellcheck
    shfmt
    
    # Testing tools
    bats
    shunit2
    
    # Documentation tools
    pandoc
    graphviz
    
    # Custom tools
    my-custom-tool
  ];
  
  shellHook = ''
    export NIXOS_CONTROL_CENTER_DEV=1
    export NIXOS_CONTROL_CENTER_LOG_LEVEL=debug
    
    echo "Development environment loaded"
  '';
}
```

#### Custom Build Configuration
```nix
# flake.nix
{
  outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
        # Development dependencies
      ];
    };
    
    packages.x86_64-linux.nixos-control-center = nixpkgs.legacyPackages.x86_64-linux.callPackage ./default.nix {};
  };
}
```

### Continuous Integration

#### Local CI Testing
```bash
# Run full CI pipeline locally
nixos-control-center dev ci

# Run specific CI stage
nixos-control-center dev ci --stage test

# Run CI with custom configuration
nixos-control-center dev ci --config ci-local.yaml
```

#### CI Configuration
```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: DeterminateSystems/nix-installer-action@main
      - run: nixos-control-center dev ci
```

## Getting Help

### Development Resources
- **Documentation**: Check the [Documentation](../docs/)
- **Issues**: Report bugs on [GitHub Issues](https://github.com/fr4iser90/NixOSControlCenter/issues)
- **Discussions**: Join [GitHub Discussions](https://github.com/fr4iser90/NixOSControlCenter/discussions)
- **Wiki**: Check the [Project Wiki](https://github.com/fr4iser90/NixOSControlCenter/wiki)

### Development Tools
- **Development Commands**: `nixos-control-center dev --help`
- **Testing Commands**: `nixos-control-center test --help`
- **Build Commands**: `nixos-control-center build --help`

### Community
- **IRC**: #nixos-control-center on Libera.Chat
- **Matrix**: #nixos-control-center:matrix.org
- **Discord**: NixOSControlCenter Discord server

This development setup guide provides everything you need to start contributing to NixOSControlCenter. For specific questions or issues, please check the documentation or reach out to the community.
