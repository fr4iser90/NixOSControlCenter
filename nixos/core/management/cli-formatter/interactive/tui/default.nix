# Bubble Tea TUI Build Integration
{ lib, pkgs, bubbletea-src ? "github.com/charmbracelet/bubbletea" }:

let
  # Import all templates
  templates = import ./components/templates.nix { inherit lib bubbletea-src; };
  listTemplate = import ./components/list.nix { inherit lib bubbletea-src; };
  formTemplate = import ./components/form.nix { inherit lib bubbletea-src; };
  statusTemplate = import ./components/status.nix { inherit lib bubbletea-src; };
  mainEntry = import ./main.nix { inherit lib bubbletea-src; };

  # Generate go.mod and go.sum from Nix
  goMod = ''
    module github.com/yourname/ncc-tui

    go 1.21

    require (
    	github.com/charmbracelet/bubbletea v0.25.0
    	github.com/charmbracelet/lipgloss v0.9.1
    )
  '';

  goSum = ''
    github.com/charmbracelet/bubbletea v0.25.0 h1:bA0UgIS6X5EdGHLQfw9T4K9PNpJyH1fMQwyM5M8HdFg=
    github.com/charmbracelet/bubbletea v0.25.0/go.mod h1:EN3QDR1T5ZdWmdfDvYUrCaKs4psWFCsN5YosNLf3KkFQ=
    github.com/charmbracelet/lipgloss v0.9.1 h1:PNQUbEE6vKUrKwvqh0i89q1M6J1b+nP/9DBH5f4zf+Y=
    github.com/charmbracelet/lipgloss v0.9.1/go.mod h1:EZLha/HbzEt7cYqdFPovlqy5FZPj0s/uyIcpxJErym0=
    github.com/mattn/go-runewidth v0.0.15 h1:UNAjwbU9l54TA3KzvqLGxwWjHmMgBUVhBiTjelZgg3U=
    github.com/mattn/go-runewidth v0.0.15/go.mod h1:Jdepj2loyihRzMpdS35Xk/zdY8IAYHsh153qUoGf23w=
    github.com/rivo/uniseg v0.4.4 h1:8Zb4qgV6WgX8a1EVAXXBkSUpo+o/bg87Fs4M8GV61so=
    github.com/rivo/uniseg v0.4.4/go.mod h1:FN3SvrM9Xkks13bq87NUuhlJZV5wRl3lMizDhsXnPVg=
  '';

  # Combine all Go files into one project
  src = pkgs.runCommand "ncc-tui-src" {} ''
    mkdir -p $out/components

    # Copy Go files
    cp ${mainEntry} $out/main.go
    cp ${templates.templatesGo} $out/components/templates.go
    cp ${listTemplate} $out/components/list.go
    cp ${formTemplate} $out/components/form.go
    cp ${statusTemplate} $out/components/status.go

    # Generate Go module files from Nix
    cat > $out/go.mod << 'EOF'
    ${goMod}
    EOF

    cat > $out/go.sum << 'EOF'
    ${goSum}
    EOF
  '';

in {
  # Build the TUI binary
  ncc-tui = pkgs.buildGoModule {
    pname = "ncc-tui";
    version = "0.1.0";
    inherit src;

    vendorSha256 = null; # Will be computed on first build

    meta = with lib; {
      description = "Modern TUI for NixOS Control Center using Bubble Tea";
      license = licenses.mit;
      maintainers = [ ];
    };
  };

  # For development/testing - run without building
  ncc-tui-dev = pkgs.writeScriptBin "ncc-tui-dev" ''
    #!/usr/bin/env bash
    cd ${src}
    go run .
  '';

  # Expose templates for other modules to use
  templates = {
    inherit listTemplate formTemplate statusTemplate;
    all = templates.templatesGo;
  };
}
