let
  inherit (builtins) fetchTree fromJSON readFile;
  lock = fromJSON (readFile ./flake.lock);
  nodes = lock.nodes or {};
  nixpkgs = nodes.nixpkgs or (fromJSON (readFile ../flake.lock)).nodes.nixpkgs;
  gomod2nixNode = nodes.gomod2nix or (fromJSON (readFile ../flake.lock)).nodes.gomod2nix;
  pkgs = import (fetchTree nixpkgs.locked) {
    overlays = [
      (import "${fetchTree gomod2nixNode.locked}/overlay.nix")
    ];
  };
in
pkgs.mkShell {
  packages = with pkgs; [
    go_1_25
    gopls
    gotools
    go-tools
    gomod2nix
  ];

  shellHook = ''
    echo "TUI Engine Development Environment"
    echo "Go version: $(go version)"
    echo ""
    echo "Available commands:"
    echo "  gomod2nix                    - Generate gomod2nix.toml"
    echo "  go run src/main.go          - Run the TUI"
    echo "  go build -o tui-engine      - Build the binary"
  '';
}
