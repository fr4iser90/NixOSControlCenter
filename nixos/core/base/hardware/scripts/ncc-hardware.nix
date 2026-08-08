# ncc hardware — status (configured + detected) and auto-detect toggle
{ pkgs, getModuleMetadata }:

let
  smRoot = (getModuleMetadata "system-manager").path;
  facade = import "${smRoot}/lib/config-facade.nix" { inherit pkgs; };
in
pkgs.writeShellScriptBin "ncc-hardware" ''
  set -euo pipefail
  export PATH="${pkgs.jq}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.util-linux}/bin:${pkgs.pciutils}/bin:${pkgs.nix}/bin:$PATH"

  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
  export NIXOS_ROOT="$NIXOS_DIR"
  export CONFIGS_BASE="$NIXOS_DIR/systemConfig"
  export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"

  usage() {
    cat <<EOF
ncc hardware — Hardware inventory and auto-detection

Usage:
  ncc hardware status [--json]
  ncc hardware set autoDetect=true|false

status   Configured CPU/GPU/RAM vs live detection; autoDetect (= system-manager.enableChecks)
set      Toggle hardware auto-detection checks (writes enableChecks; needs root)
EOF
  }

  read_hw_json() {
    local tmp_nix tmp_json
    tmp_nix=$(mktemp --suffix=.nix)
    tmp_json=$(mktemp --suffix=.json)
    ncc_read_module_config "core/base/hardware" > "$tmp_nix" 2>/dev/null || printf '%s\n' '{}' > "$tmp_nix"
    if ! nix-instantiate --eval --strict --json -E "import $tmp_nix" > "$tmp_json" 2>/dev/null; then
      printf '%s\n' '{}' > "$tmp_json"
    fi
    cat "$tmp_json"
    rm -f "$tmp_nix" "$tmp_json"
  }

  read_sm_json() {
    local tmp_nix tmp_json
    tmp_nix=$(mktemp --suffix=.nix)
    tmp_json=$(mktemp --suffix=.json)
    ncc_read_module_config "core/management/system-manager" > "$tmp_nix" 2>/dev/null || printf '%s\n' '{}' > "$tmp_nix"
    if ! nix-instantiate --eval --strict --json -E "import $tmp_nix" > "$tmp_json" 2>/dev/null; then
      printf '%s\n' '{}' > "$tmp_json"
    fi
    cat "$tmp_json"
    rm -f "$tmp_nix" "$tmp_json"
  }

  detect_cpu() {
    local info
    info=$(lscpu 2>/dev/null || true)
    if echo "$info" | grep -qi "GenuineIntel"; then
      echo "intel"
    elif echo "$info" | grep -qi "AuthenticAMD"; then
      echo "amd"
    else
      echo "none"
    fi
  }

  detect_gpu() {
    local pci has_nvidia=0 has_amd=0 has_intel=0
    pci=$(lspci -nn 2>/dev/null || true)
    if ! echo "$pci" | grep -qiE 'VGA|3D|Display'; then
      echo "none"
      return
    fi
    if echo "$pci" | grep -iE 'VGA|3D|Display' | grep -qi 'NVIDIA\|10de:'; then has_nvidia=1; fi
    if echo "$pci" | grep -iE 'VGA|3D|Display' | grep -qiE 'AMD|ATI|1002:'; then has_amd=1; fi
    if echo "$pci" | grep -iE 'VGA|3D|Display' | grep -qi 'Intel\|8086:'; then has_intel=1; fi
    if [[ "$has_nvidia" -eq 1 && "$has_intel" -eq 1 ]]; then echo "nvidia-intel"
    elif [[ "$has_amd" -eq 1 && "$has_intel" -eq 1 ]]; then echo "amd-intel"
    elif [[ "$has_nvidia" -eq 1 ]]; then echo "nvidia"
    elif [[ "$has_amd" -eq 1 ]]; then echo "amd"
    elif [[ "$has_intel" -eq 1 ]]; then echo "intel"
    else echo "none"
    fi
  }

  detect_ram_gb() {
    local kib raw
    kib=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    raw=$(( (kib + 524288) / 1048576 ))
    if [[ "$raw" -ge 56 ]]; then echo 64
    elif [[ "$raw" -ge 28 ]]; then echo 32
    elif [[ "$raw" -ge 14 ]]; then echo 16
    elif [[ "$raw" -ge 6 ]]; then echo 8
    elif [[ "$raw" -ge 3 ]]; then echo 4
    else echo "$raw"
    fi
  }

  cmd_status() {
    local json_out=false
    for a in "$@"; do
      case "$a" in --json|-j) json_out=true ;; esac
    done

    local hw sm
    hw=$(read_hw_json)
    sm=$(read_sm_json)

    local cpu_cfg gpu_cfg ram_cfg auto
    cpu_cfg=$(echo "$hw" | jq -r '.cpu // "none"')
    gpu_cfg=$(echo "$hw" | jq -r '.gpu // "none"')
    ram_cfg=$(echo "$hw" | jq -r 'if .ram.sizeGB == null then "null" else (.ram.sizeGB|tostring) end')
    auto=$(echo "$sm" | jq -r 'if .enableChecks == false then "false" else "true" end')

    local cpu_det gpu_det ram_det
    cpu_det=$(detect_cpu)
    gpu_det=$(detect_gpu)
    ram_det=$(detect_ram_gb)

    if [[ "$json_out" == true ]]; then
      jq -nc \
        --arg cpuCfg "$cpu_cfg" --arg gpuCfg "$gpu_cfg" --arg ramCfg "$ram_cfg" \
        --arg cpuDet "$cpu_det" --arg gpuDet "$gpu_det" --argjson ramDet "$ram_det" \
        --argjson autoDetect "$( [[ "$auto" == true ]] && echo true || echo false )" \
        '{
          autoDetect: $autoDetect,
          configured: {
            cpu: $cpuCfg,
            gpu: $gpuCfg,
            ramGB: (if $ramCfg == "null" then null else ($ramCfg|tonumber) end)
          },
          detected: {
            cpu: $cpuDet,
            gpu: $gpuDet,
            ramGB: $ramDet
          },
          match: {
            cpu: ($cpuCfg == $cpuDet),
            gpu: ($gpuCfg == $gpuDet),
            ram: (if $ramCfg == "null" then false else (($ramCfg|tonumber) == $ramDet) end)
          }
        }'
    else
      echo "autoDetect=$auto"
      echo "configured.cpu=$cpu_cfg"
      echo "configured.gpu=$gpu_cfg"
      echo "configured.ramGB=$ram_cfg"
      echo "detected.cpu=$cpu_det"
      echo "detected.gpu=$gpu_det"
      echo "detected.ramGB=$ram_det"
    fi
  }

  cmd_set() {
    local auto=""
    for arg in "$@"; do
      case "$arg" in
        autoDetect=true|autoDetect=false) auto="''${arg#autoDetect=}" ;;
        enableChecks=true|enableChecks=false) auto="''${arg#enableChecks=}" ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown: $arg" >&2; usage >&2; exit 2 ;;
      esac
    done
    [[ -n "$auto" ]] || { echo "Usage: ncc hardware set autoDetect=true|false" >&2; exit 2; }

    if [[ "''${EUID:-$(id -u)}" -ne 0 ]]; then
      echo "Run as root: sudo ncc hardware set autoDetect=$auto" >&2
      exit 1
    fi

    local sm
    sm=$(ncc_read_module_config "core/management/system-manager" 2>/dev/null || echo "{}")
    if echo "$sm" | grep -qE 'enableChecks[[:space:]]*='; then
      sm=$(echo "$sm" | sed -E "s/enableChecks[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*;/enableChecks = $auto;/")
    elif [ "$sm" = "{}" ] || [ -z "$(echo "$sm" | tr -d '[:space:]')" ]; then
      sm="{
  enableChecks = $auto;
}"
    else
      sm=$(printf '%s\n' "$sm" | sed "\$ i\\  enableChecks = $auto;")
    fi
    ncc_write_module_config "core/management/system-manager" "$sm"
    echo "OK: autoDetect=$auto (system-manager.enableChecks)"
  }

  case "''${1:-}" in
    ""|help|-h|--help) usage ;;
    status) shift; cmd_status "$@" ;;
    set) shift; cmd_set "$@" ;;
    *)
      echo "Unknown: ncc hardware $1" >&2
      usage >&2
      exit 2
      ;;
  esac
''
