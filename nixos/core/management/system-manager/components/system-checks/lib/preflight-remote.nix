# Shared remote/compare preflight helpers for prebuild-check-* (SSOT).
{
  # Inject into prebuild-check-{platform,cpu,gpu,memory} after CONFIGURED + DETECTED are set.
  # Plain echo — messages use bash vars (must not use ui.badges with ''${label} at Nix eval time).
  bashHelpers = ''
    # NCC_PREFLIGHT_MODE: heal (default, local update) | compare (remote install — no writes)
    _ncc_preflight_is_compare() {
      [ "''${NCC_PREFLIGHT_MODE:-heal}" = "compare" ]
    }

    # Compare-only exit: returns 0 if heal mode should continue; exits 0 on match or 1 on fail.
    _ncc_preflight_compare_only() {
      local label="$1" configured="$2" detected="$3"
      _ncc_preflight_is_compare || return 0
      if [ -z "$configured" ]; then
        echo "ERROR: ''${label}: unset in systemConfig (remote compare)" >&2
        exit 1
      fi
      if [ -z "$detected" ] || [ "$detected" = "unknown" ]; then
        echo "ERROR: ''${label}: could not detect live value (configured=''${configured})" >&2
        exit 1
      fi
      if [ "$detected" != "$configured" ]; then
        echo "ERROR: ''${label}: systemConfig=''${configured} live=''${detected}" >&2
        exit 1
      fi
      echo "OK: ''${label}: ''${detected}"
      exit 0
    }
  '';

  # Step manifest for remote install (Host pipes each script to Target via SSH).
  remoteInstallSteps = [
    { cmd = "prebuild-check-users"; env = { }; }
    { cmd = "prebuild-check-platform"; env = { NCC_PREFLIGHT_MODE = "compare"; }; }
    { cmd = "prebuild-check-cpu"; env = { NCC_PREFLIGHT_MODE = "compare"; }; }
    { cmd = "prebuild-check-gpu"; env = { NCC_PREFLIGHT_MODE = "compare"; }; }
    { cmd = "prebuild-check-memory"; env = { NCC_PREFLIGHT_MODE = "compare"; }; }
  ];
}
