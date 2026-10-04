# Qwen Code harness for NCC AI (`ncc ai … --harness qwen`).
#
# Activation: copy/rename to e.g. `qwen_code_harness.nix`
# (`example_*` files are NOT auto-imported by custom/default.nix), then rebuild.
#
# Prefers nixpkgs `qwen-code` (no npm -g). Wraps `qwen` so TMPDIR lands on
# disk under ~/.cache (tmpfs /tmp + huge Electron caches → ENOSPC/OOM).
#
# After rebuild:
#   ncc ai harness probe qwen
#   ncc ai agent run --harness qwen --goal "Summarize this repo"
#
# Optional: register NCC tools inside Qwen MCP settings → `ncc ai mcp`.
{ lib, pkgs, getModuleMetadata, ... }:

let
  nccMeta = getModuleMetadata "ncc-assistant";
  cfgPath = nccMeta.configPath;

  qwenPkg = pkgs.qwen-code;

  # Disk-backed temp for Qwen/dotslash caches (avoid filling tmpfs /tmp).
  qwenBin = pkgs.writeShellApplication {
    name = "qwen";
    runtimeInputs = [ qwenPkg pkgs.coreutils ];
    text = ''
      set -euo pipefail
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/qwen-code"
      export TMPDIR="''${QWEN_TMPDIR:-$cache/tmp}"
      export npm_config_cache="''${npm_config_cache:-$cache/npm}"
      mkdir -p "$TMPDIR" "$npm_config_cache"
      exec ${lib.getExe qwenPkg} "$@"
    '';
  };
in
{
  environment.systemPackages = [ qwenBin ];

  # Tell NCC adapters which binary to use (wrapper on PATH is enough; env is explicit).
  environment.sessionVariables = {
    NCC_ASSISTANT_QWEN_BIN = "${qwenBin}/bin/qwen";
  };

  # Soft-wire NCC assistant (does not force enable=true).
  # Nested write — never systemConfig.${cfgPath} (dotted key ≠ nested path).
  # Override in live systemConfig if you want codingHarness = "qwen" always.
  systemConfig = lib.setAttrByPath (lib.splitString "." cfgPath) {
    agent.codingHarness = lib.mkDefault "auto";
  };
}
