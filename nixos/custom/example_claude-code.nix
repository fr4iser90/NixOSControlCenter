{ config, lib, pkgs, ... }:

let
  version = "2.1.305";

  # Seed binary in the store. Never put this directly on PATH as `claude` —
  # that would shadow ~/.local/bin and break `claude update`.
  claudeCodeSeed = pkgs.stdenvNoCC.mkDerivation {
    pname = "claude-code-seed";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/linux-x64/claude";
      hash = "sha256-hstyKraDSId9unlx5NDGWZGeBeYijAXgBug9oyDmVu8=";
    };

    dontUnpack = true;
    dontStrip = true;

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];

    buildInputs = [
      pkgs.procps
      pkgs.ripgrep
      pkgs.bubblewrap
      pkgs.socat
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/libexec/claude-code/claude"
      runHook postInstall
    '';

    meta = {
      description = "Anthropic Claude Code bootstrap seed";
      homepage = "https://claude.com/product/claude-code";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };

  # First run copies the seed into ~/.local/bin; every run execs that copy.
  # `claude update` then replaces ~/.local/bin/claude — which is what we exec.
  claudeCode = pkgs.writeShellScriptBin "claude" ''
    set -euo pipefail
    target="''${HOME}/.local/bin/claude"
    if [[ ! -x "$target" ]]; then
      mkdir -p "$(dirname "$target")"
      cp -f "${claudeCodeSeed}/libexec/claude-code/claude" "$target"
      chmod +x "$target"
    fi
    export USE_BUILTIN_RIPGREP="''${USE_BUILTIN_RIPGREP:-0}"
    export PATH="${lib.makeBinPath [
      pkgs.procps
      pkgs.ripgrep
      pkgs.bubblewrap
      pkgs.socat
    ]}:''${PATH}"
    exec "$target" "$@"
  '';
in
{
  # After seed/update, prefer ~/.local/bin over the wrapper when both exist.
  environment.localBinInPath = true;

  environment.systemPackages = [
    claudeCode
    pkgs.procps
    pkgs.ripgrep
    pkgs.bubblewrap
    pkgs.socat
  ];
}
