# ncc hardware — status (configured + detected enums + live probe) and auto-detect toggle
{ pkgs, getModuleMetadata, getModuleApi }:

let
  ui = getModuleApi "cli-formatter";
  smRoot = (getModuleMetadata "system-manager").path;
  facade = import "${smRoot}/lib/config-facade.nix" { inherit pkgs; };
in
pkgs.writeShellScriptBin "ncc-hardware" ''
  set -euo pipefail
  export PATH="${pkgs.jq}/bin:${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.util-linux}/bin:${pkgs.pciutils}/bin:${pkgs.nix}/bin:$PATH"

  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
  export NIXOS_ROOT="$NIXOS_DIR"
  export CONFIGS_BASE="$NIXOS_DIR/systemConfig"
  export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"

  usage() {
    cat <<EOF
ncc hardware — Hardware inventory and auto-detection

Usage:
  ncc hardware status [--json] [-v]
  ncc hardware set autoDetect=true|false [--dry-run] [-v]

status   Configured enums vs check enums + live probe (models); autoDetect (= enableChecks)
set      Toggle hardware auto-detection checks (writes enableChecks; needs root)

Probe details are live-only (not written to systemConfig).
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

  # Live probe — human-readable; never written to systemConfig
  probe_json() {
    local model cores threads mhz_max kib exact_gb
    model=$(lscpu 2>/dev/null | awk -F: '/Model name/ { sub(/^[ \t]+/, "", $2); print $2; exit }' || true)
    [[ -n "$model" ]] || model="unknown"
    cores=$(lscpu 2>/dev/null | awk -F: '/^Core\(s\) per socket/ { gsub(/[ \t]/,"",$2); c=$2 }
      /^Socket\(s\)/ { gsub(/[ \t]/,"",$2); s=$2 }
      END { if (c+0 > 0 && s+0 > 0) print c*s; else print 0 }' || echo 0)
    threads=$(nproc 2>/dev/null || echo 0)
    mhz_max=$(lscpu 2>/dev/null | awk -F: '/CPU max MHz/ { gsub(/[ \t]/,"",$2); print $2; exit }' || true)
    [[ -n "$mhz_max" ]] || mhz_max="null"

    kib=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    exact_gb=$(awk -v k="$kib" 'BEGIN { printf "%.1f", k/1048576 }')

    local gpus_json
    gpus_json=$(
      lspci -nn 2>/dev/null | grep -iE 'VGA|3D|Display' | while IFS= read -r line; do
        addr=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | sed -E 's/^[0-9a-f:.]+[[:space:]]+([^:]+:[[:space:]]*)?//; s/[[:space:]]*\[[0-9a-f]{4}:[0-9a-f]{4}\].*$//; s/[[:space:]]*\(rev [^)]*\)[[:space:]]*$//')
        vendor="other"
        echo "$line" | grep -qi 'NVIDIA\|10de:' && vendor="nvidia"
        echo "$line" | grep -qiE 'AMD|ATI|1002:' && vendor="amd"
        echo "$line" | grep -qi 'Intel\|8086:' && vendor="intel"
        jq -nc --arg a "$addr" --arg n "$name" --arg v "$vendor" '{address:$a, name:$n, vendor:$v}'
      done | jq -s '.'
    )
    [[ -n "$gpus_json" ]] || gpus_json='[]'

    jq -nc \
      --arg model "$model" \
      --argjson cores "$cores" \
      --argjson threads "$threads" \
      --arg mhzMax "$mhz_max" \
      --argjson exactGB "$exact_gb" \
      --argjson kib "$kib" \
      --argjson gpus "$gpus_json" \
      '{
        cpu: {
          model: $model,
          cores: $cores,
          threads: $threads,
          maxMHz: (if $mhzMax == "null" then null else ($mhzMax|tonumber) end)
        },
        gpus: $gpus,
        ram: {
          totalGiB: $exactGB,
          totalKiB: $kib
        }
      }'
  }

  cmd_status() {
    local json_out=false verbose=false
    for a in "$@"; do
      case "$a" in
        --json|-j) json_out=true ;;
        --verbose|-v) verbose=true ;;
      esac
    done

    if [[ "$json_out" != true && -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "Hardware status"}
    fi
    if [[ "$json_out" != true ]]; then
      ${ui.messages.loading "Reading hardware configuration and probing…"}
    fi

    local hw sm
    hw=$(read_hw_json)
    sm=$(read_sm_json)

    local cpu_cfg gpu_cfg ram_cfg auto
    cpu_cfg=$(echo "$hw" | jq -r '.cpu // "none"')
    gpu_cfg=$(echo "$hw" | jq -r '.gpu // "none"')
    ram_cfg=$(echo "$hw" | jq -r 'if .ram.sizeGB == null then "null" else (.ram.sizeGB|tostring) end')
    auto=$(echo "$sm" | jq -r 'if .enableChecks == false then "false" else "true" end')

    local cpu_det gpu_det ram_det probed
    cpu_det=$(detect_cpu)
    gpu_det=$(detect_gpu)
    ram_det=$(detect_ram_gb)
    probed=$(probe_json)

    if [[ "$json_out" == true ]]; then
      jq -nc \
        --arg cpuCfg "$cpu_cfg" --arg gpuCfg "$gpu_cfg" --arg ramCfg "$ram_cfg" \
        --arg cpuDet "$cpu_det" --arg gpuDet "$gpu_det" --argjson ramDet "$ram_det" \
        --argjson autoDetect "$( [[ "$auto" == true ]] && echo true || echo false )" \
        --argjson probed "$probed" \
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
          },
          probed: $probed
        }'
    else
      ${ui.tables.keyValue "autoDetect" "$auto"}
      ${ui.tables.keyValue "configured.cpu" "$cpu_cfg"}
      ${ui.tables.keyValue "configured.gpu" "$gpu_cfg"}
      ${ui.tables.keyValue "configured.ramGB" "$ram_cfg"}
      ${ui.tables.keyValue "detected.cpu" "$cpu_det"}
      ${ui.tables.keyValue "detected.gpu" "$gpu_det"}
      ${ui.tables.keyValue "detected.ramGB" "$ram_det"}
      if [[ "$verbose" == true ]]; then
        _m=$(echo "$probed" | jq -r '.cpu.model')
        _c=$(echo "$probed" | jq -r '.cpu.cores')
        _t=$(echo "$probed" | jq -r '.cpu.threads')
        _mhz=$(echo "$probed" | jq -r '.cpu.maxMHz // "null"')
        _ram=$(echo "$probed" | jq -r '.ram.totalGiB')
        ${ui.tables.keyValue "probed.cpu.model" "$_m"}
        ${ui.tables.keyValue "probed.cpu.cores" "$_c"}
        ${ui.tables.keyValue "probed.cpu.threads" "$_t"}
        ${ui.tables.keyValue "probed.cpu.maxMHz" "$_mhz"}
        ${ui.tables.keyValue "probed.ram.totalGiB" "$_ram"}
        local i n
        n=$(echo "$probed" | jq '.gpus | length')
        for ((i=0; i<n; i++)); do
          _g=$(echo "$probed" | jq -r --argjson i "$i" '.gpus[$i] | "\(.vendor): \(.name)"')
          ${ui.tables.keyValue "probed.gpu.$i" "$_g"}
        done
      fi
      ${ui.messages.success "Hardware status ready"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc hardware set autoDetect=true|false"}
      fi
    fi
  }

  cmd_set() {
    local auto="" dry_run=false verbose=false
    for arg in "$@"; do
      case "$arg" in
        autoDetect=true|autoDetect=false) auto="''${arg#autoDetect=}" ;;
        enableChecks=true|enableChecks=false) auto="''${arg#enableChecks=}" ;;
        --dry-run|-d) dry_run=true ;;
        --verbose|-v) verbose=true ;;
        --help|-h) usage; exit 0 ;;
        *)
          ${ui.messages.error "Unknown: $arg"}
          usage >&2
          if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
            ${ui.messages.info "Next: sudo ncc hardware set autoDetect=true|false"}
          fi
          exit 2
          ;;
      esac
    done
    if [[ -z "$auto" ]]; then
      ${ui.messages.error "Usage: ncc hardware set autoDetect=true|false"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: sudo ncc hardware set autoDetect=true|false"}
      fi
      exit 2
    fi

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      if [[ "$dry_run" == true ]]; then
        ${ui.text.header "Hardware set (dry-run)"}
        ${ui.messages.info "Preview only — nothing will be written…"}
      else
        ${ui.text.header "Hardware set"}
      fi
    fi

    if [[ "''${EUID:-$(id -u)}" -ne 0 ]] && [[ "$dry_run" != true ]]; then
      ${ui.messages.error "Run as root: sudo ncc hardware set autoDetect=$auto"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: sudo ncc hardware set autoDetect=$auto"}
      fi
      exit 1
    fi

    ${ui.messages.loading "Updating autoDetect (enableChecks)…"}
    ${ui.tables.keyValue "autoDetect" "$auto"}
    if [[ "$verbose" == true ]]; then
      ${ui.tables.keyValue "NIXOS_DIR" "$NIXOS_DIR"}
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

    if [[ "$dry_run" == true ]]; then
      ${ui.messages.success "Would set autoDetect=$auto (dry-run) — no changes written"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: sudo ncc hardware set autoDetect=$auto"}
      fi
      exit 0
    fi

    ncc_write_module_config "core/management/system-manager" "$sm"
    ${ui.messages.success "autoDetect=$auto (system-manager.enableChecks)"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc hardware status"}
    fi
  }

  case "''${1:-}" in
    ""|help|-h|--help) usage ;;
    status) shift; cmd_status "$@" ;;
    set) shift; cmd_set "$@" ;;
    *)
      ${ui.messages.error "Unknown: ncc hardware $1"}
      usage >&2
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc hardware status"}
      fi
      exit 2
      ;;
  esac
''
