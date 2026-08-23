# Secure Node/npm/npx + Playwright browsers (Nix-managed).
#
# Activation: copy/rename to e.g. `node.nix` (files prefixed `example_` are
# NOT auto-imported by custom/default.nix), then rebuild.
#
# Playwright: do NOT `npm install -g playwright` / `npx playwright install
# --with-deps`. Browsers come from nixpkgs; npm packages stay per-project.
#
# Agent / AI escape hatches (opt-in, never default-on):
#   NPM_SECURITY_ALLOW_AUDIT_FAIL=1   — warn + continue install if audit fails
#   NPM_SECURITY_ALLOW_NPX_UNAUDITED=1 — skip npx package audit (broad; prefer local .bin)
#   NPM_SECURITY_ALLOW_GLOBAL=1       — allow `npm -g` (still discouraged)
# Do not teach agents to call /nix/store/.../bin/npm directly — that bypasses
# the wrapper entirely.
{ pkgs, lib, ... }:

let
  node = pkgs.nodejs_22 or pkgs.nodejs;

  # Official Playwright browser cache from nixpkgs (matches driver ~1.59.x).
  # Pin project @playwright/test near this version, or launch via executablePath.
  playwrightBrowsers = pkgs.playwright-driver.browsers-chromium;

  secureNpm = pkgs.writeShellApplication {
    name = "npm";
    runtimeInputs = [ node pkgs.coreutils pkgs.rsync ];
    text = ''
      set -euo pipefail

      real_npm="${node}/bin/npm"
      audit_level="''${NPM_AUDIT_LEVEL:-moderate}"
      cmd="''${1:-}"

      is_global=0
      for arg in "$@"; do
        case "$arg" in
          -g|--global) is_global=1 ;;
        esac
      done

      if [[ "$is_global" == "1" && "''${NPM_SECURITY_ALLOW_GLOBAL:-0}" != "1" ]]; then
        echo "Blocked: global npm installs are disabled by secure npm wrapper." >&2
        echo "Use NPM_SECURITY_ALLOW_GLOBAL=1 only if you really trust this install." >&2
        echo "For Playwright browsers, use Nix (PLAYWRIGHT_BROWSERS_PATH) — not npm -g." >&2
        exit 42
      fi

      run_audit() {
        if "$real_npm" audit --audit-level="$audit_level"; then
          return 0
        fi
        local status=$?
        if [[ "''${NPM_SECURITY_ALLOW_AUDIT_FAIL:-0}" == "1" ]]; then
          echo "secure-npm: WARNING: audit failed (exit $status) but NPM_SECURITY_ALLOW_AUDIT_FAIL=1 — continuing." >&2
          return 0
        fi
        echo "secure-npm: audit failed (level=$audit_level, exit $status)." >&2
        echo "Fix vulnerabilities, lower NPM_AUDIT_LEVEL, or set NPM_SECURITY_ALLOW_AUDIT_FAIL=1 for agents." >&2
        return "$status"
      }

      case "$cmd" in
        install|i|add|update)
          project_root="$("$real_npm" prefix 2>/dev/null || pwd)"
          tmp="$(mktemp -d)"
          trap 'rm -rf "$tmp"' EXIT

          rsync -a \
            --exclude node_modules \
            --exclude .git \
            --exclude dist \
            --exclude build \
            "$project_root"/ "$tmp"/

          cd "$tmp"

          echo "secure-npm: resolving dependency tree without running install scripts..."
          "$real_npm" "$@" --package-lock-only --ignore-scripts --no-audit

          echo "secure-npm: auditing dependency tree, level=$audit_level..."
          run_audit

          cd "$project_root"
          # Clear EXIT trap before exec so tmp cleanup does not race the real install.
          trap - EXIT
          rm -rf "$tmp"
          exec "$real_npm" "$@"
          ;;

        ci)
          echo "secure-npm: auditing package-lock before npm ci, level=$audit_level..."
          run_audit
          exec "$real_npm" "$@"
          ;;

        *)
          exec "$real_npm" "$@"
          ;;
      esac
    '';
  };

  secureNpx = pkgs.writeShellApplication {
    name = "npx";
    runtimeInputs = [ node pkgs.coreutils ];
    text = ''
      set -euo pipefail

      real_npm="${node}/bin/npm"
      real_npx="${node}/bin/npx"
      audit_level="''${NPM_AUDIT_LEVEL:-moderate}"

      if [[ "''${NPM_SECURITY_ALLOW_NPX_UNAUDITED:-0}" == "1" ]]; then
        echo "secure-npx: WARNING: running without audit because NPM_SECURITY_ALLOW_NPX_UNAUDITED=1" >&2
        exec "$real_npx" "$@"
      fi

      packages=()
      expect_package=0

      for arg in "$@"; do
        if [[ "$expect_package" == "1" ]]; then
          packages+=("$arg")
          expect_package=0
          continue
        fi

        case "$arg" in
          -h|--help|-v|--version)
            exec "$real_npx" "$@"
            ;;
          -p|--package)
            expect_package=1
            ;;
          --package=*)
            packages+=("''${arg#--package=}")
            ;;
          --)
            break
            ;;
          -*)
            ;;
          *)
            project_root="$("$real_npm" prefix 2>/dev/null || pwd)"
            if [[ -x "./node_modules/.bin/$arg" || -x "$project_root/node_modules/.bin/$arg" ]]; then
              echo "secure-npx: using local executable without downloading packages..."
              exec "$real_npx" --no-install "$@"
            fi

            packages+=("$arg")
            break
            ;;
        esac
      done

      if [[ "$expect_package" == "1" ]]; then
        echo "Blocked: npx package flag requires a package name." >&2
        exit 42
      fi

      if [[ "''${#packages[@]}" == "0" ]]; then
        echo "Blocked: npx command could not be mapped to an auditable package." >&2
        echo "Use 'npx --package <package> <command>' or install the tool locally first." >&2
        exit 42
      fi

      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      cd "$tmp"

      "$real_npm" init -y >/dev/null

      echo "secure-npx: resolving package(s) without running install scripts: ''${packages[*]}"
      "$real_npm" install --package-lock-only --ignore-scripts --no-audit "''${packages[@]}"

      echo "secure-npx: auditing dependency tree, level=$audit_level..."
      if ! "$real_npm" audit --audit-level="$audit_level"; then
        status=$?
        if [[ "''${NPM_SECURITY_ALLOW_AUDIT_FAIL:-0}" == "1" ]]; then
          echo "secure-npx: WARNING: audit failed (exit $status) but NPM_SECURITY_ALLOW_AUDIT_FAIL=1 — continuing." >&2
        else
          echo "secure-npx: audit failed (level=$audit_level, exit $status)." >&2
          echo "Fix vulnerabilities or set NPM_SECURITY_ALLOW_AUDIT_FAIL=1 for agents." >&2
          exit "$status"
        fi
      fi

      echo "secure-npx: audit passed (or allow-fail), executing npx..."
      trap - EXIT
      rm -rf "$tmp"
      exec "$real_npx" "$@"
    '';
  };

  secureNode = pkgs.symlinkJoin {
    name = "secure-node";
    paths = [ node ];
    postBuild = ''
      rm -f $out/bin/npm $out/bin/npx
      ln -s ${secureNpm}/bin/npm $out/bin/npm
      ln -s ${secureNpx}/bin/npx $out/bin/npx
    '';
  };
in
{
  environment.systemPackages = [
    secureNode
    pkgs.pnpm
    pkgs.yarn
    # System Chromium as fallback launch target (version-flexible).
    pkgs.chromium
  ];

  # Some tools spawn /usr/bin/bash with a minimal PATH and miss the NixOS
  # system profile. Provide stable FHS-style entry points for those callers.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/bash - - - - ${pkgs.bash}/bin/bash"
    "L+ /usr/bin/node - - - - ${secureNode}/bin/node"
    "L+ /usr/bin/npm - - - - ${secureNode}/bin/npm"
    "L+ /usr/bin/npx - - - - ${secureNode}/bin/npx"
  ];

  environment.sessionVariables = {
    NPM_AUDIT_LEVEL = "moderate";

    # Browsers from Nix — npm postinstall must not download Chromium.
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    PLAYWRIGHT_BROWSERS_PATH = "${playwrightBrowsers}";
    # Project configs / agents can also point launchOptions.executablePath here.
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
  };
}
