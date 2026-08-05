{ lib, pkgs }:

let
  distros = import ./distros.nix { inherit lib; };
  portManager = import ./port-manager.nix { inherit lib pkgs; };
  isoManager = import ./iso-manager.nix { inherit lib pkgs; };
in
{
  inherit (distros) distros validateDistro getDistroUrl isLocalIso getOsFamily getIsoHint;

  mkVmScript = {
    name,
    memory,
    cores,
    image,
    distro ? "nixos",
    variant ? "graphical",
    version ? null,
    stateDir ? "/var/lib/virt",
    ovmf ? pkgs.OVMF,
  }: let
    validVersion = distros.validateDistro distro variant version;
    localOnly = distros.isLocalIso distro variant;
    osFamily = distros.getOsFamily distro;
    isoHint = distros.getIsoHint distro variant;
    isoUrl = if localOnly then "" else distros.getDistroUrl distro variant validVersion;
    versionString = if validVersion == null then "latest" else validVersion;
    distroName = distros.distros.${distro}.name;
    isWindows = osFamily == "windows";
    # Win11 requires Secure Boot + MS keys; plain OVMF_CODE.fd + secure=on
    # breaks UEFI DVD boot (BdsDxe timeout → PXE). Win10 does not need SB.
    needsSecureBoot = distro == "win11";
    ovmfPkg = if needsSecureBoot then pkgs.OVMFFull else ovmf;
    ovmfCode =
      if needsSecureBoot
      then "${ovmfPkg.fd}/FV/OVMF_CODE.ms.fd"
      else "${ovmfPkg.fd}/FV/OVMF_CODE.fd";
    ovmfVarsTemplate =
      if needsSecureBoot
      then "${ovmfPkg.fd}/FV/OVMF_VARS.ms.fd"
      else "${ovmfPkg.fd}/FV/OVMF_VARS.fd";
    # Separate NVRAM files so rebuilds drop broken Secure-Boot-era VARS
    # without any manual rm/chmod.
    vars_path =
      if needsSecureBoot
      then "${stateDir}/testing/vars/${name}_VARS.ms.fd"
      else "${stateDir}/testing/vars/${name}_VARS.uefi.fd";
  in ''
    # swtpm must live in a user-writable runtime dir (not /var/lib/virt)
    SWTPM_DIR="''${XDG_RUNTIME_DIR:-/tmp}/ncc-vm/${name}/swtpm"

    function own_path() {
      local path="$1"
      local group="libvirtd"
      if ! getent group libvirtd >/dev/null 2>&1; then
        group="$USER"
      fi
      chown "$USER:$group" "$path" 2>/dev/null \
        || sudo chown "$USER:$group" "$path" 2>/dev/null \
        || true
      chmod u+rwX,g+rwX "$path" 2>/dev/null \
        || sudo chmod u+rwX,g+rwX "$path" 2>/dev/null \
        || true
    }

    function ensure_writable_dir() {
      local d="$1"
      mkdir -p "$d" 2>/dev/null || sudo mkdir -p "$d"
      if [ ! -w "$d" ]; then
        own_path "$d"
      fi
      # setgid so new files inherit libvirtd group when possible
      if getent group libvirtd >/dev/null 2>&1; then
        chmod 2775 "$d" 2>/dev/null || sudo chmod 2775 "$d" 2>/dev/null || true
      fi
      if [ ! -w "$d" ]; then
        echo "❌ Directory not writable: $d (user must be in group libvirtd; re-login after rebuild)" >&2
        exit 1
      fi
    }

    function prepare_dirs() {
      for d in \
        "${stateDir}/testing" \
        "${stateDir}/testing/vars" \
        "${stateDir}/testing/iso" \
        "${stateDir}/testing/images"
      do
        ensure_writable_dir "$d"
      done
    }

    function prepare_ovmf() {
      echo "🔧 Preparing OVMF VARS..."
      if [ ! -f "${vars_path}" ]; then
        echo "  Creating new VARS file..."
        install -Dm644 ${ovmfVarsTemplate} "${vars_path}" 2>/dev/null \
          || sudo install -Dm644 ${ovmfVarsTemplate} "${vars_path}"
      else
        echo "  Using existing VARS file"
      fi
      own_path "${vars_path}"
      # QEMU needs write access to VARS (UEFI NVRAM)
      if [ ! -w "${vars_path}" ]; then
        echo "❌ OVMF VARS not writable: ${vars_path}" >&2
        exit 1
      fi
    }

    function create_disk() {
      echo "💾 Checking VM disk..."
      ensure_writable_dir "$(dirname "${image.path}")"
      if [ ! -f "${image.path}" ]; then
        echo "  Creating new ${toString image.size}GB disk..."
        if ! ${pkgs.qemu}/bin/qemu-img create -f qcow2 "${image.path}" ${toString image.size}G; then
          sudo ${pkgs.qemu}/bin/qemu-img create -f qcow2 "${image.path}" ${toString image.size}G
        fi
        echo "  Disk created!"
      else
        echo "  Using existing disk"
      fi
      own_path "${image.path}"
      if [ ! -w "${image.path}" ]; then
        echo "❌ Disk image not writable: ${image.path}" >&2
        exit 1
      fi
    }

    # Live QEMU detection (these VMs are NOT libvirt domains)
    function qemu_pids_for_vm() {
      local pid cmdline
      for pid in $(${pkgs.procps}/bin/pgrep -f 'qemu-system-x86_64' 2>/dev/null || true); do
        cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
        case " $cmdline " in
          *" -name ${name} "*|*" -name ${name}"*)
            echo "$pid"
            ;;
        esac
      done
    }

    function spice_port_of_pid() {
      local pid="$1"
      local cmdline
      cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
      # -spice port=5900,...
      if [[ "$cmdline" =~ -spice[[:space:]]+port=([0-9]+) ]]; then
        echo "''${BASH_REMATCH[1]}"
        return 0
      fi
      echo "$cmdline" | ${pkgs.gnused}/bin/sed -n 's/.*-spice port=\([0-9][0-9]*\).*/\1/p' | head -1
    }

    function print_running_vm_help() {
      local pid="$1"
      local port="$2"
      echo "⚠️  VM ${name} is already running"
      echo "  PID:   $pid"
      if [ -n "''${port:-}" ]; then
        echo "  SPICE: spice://localhost:$port"
        echo ""
        echo "  Reconnect:  remote-viewer spice://localhost:$port"
        echo "              spicy -h localhost -p $port"
      else
        echo "  SPICE: (could not detect port from QEMU cmdline)"
      fi
      echo "  Stop:       kill $pid"
      echo "  Restart:    ncc vm test-${distro}-run --replace"
      echo "  + installer: ncc vm test-${distro}-run --iso --replace"
      echo ""
      echo "  (Blank 'Connected to graphic server' = hung guest — kill/replace)"
    }

    function stop_running_vm() {
      local pids pid port
      pids=$(qemu_pids_for_vm)
      if [ -z "''${pids:-}" ]; then
        return 0
      fi
      for pid in $pids; do
        port=$(spice_port_of_pid "$pid" || true)
        echo "🛑 Stopping ${name} (PID $pid''${port:+, SPICE :$port})..."
        kill "$pid" 2>/dev/null || true
      done
      # Wait for disk lock to release
      local i
      for i in 1 2 3 4 5 6 7 8 9 10; do
        pids=$(qemu_pids_for_vm)
        [ -z "''${pids:-}" ] && break
        sleep 0.3
      done
      pids=$(qemu_pids_for_vm)
      if [ -n "''${pids:-}" ]; then
        echo "  Force killing: $pids"
        kill -9 $pids 2>/dev/null || true
        sleep 0.3
      fi
    }

    function ensure_no_conflicting_vm() {
      local pids pid port
      pids=$(qemu_pids_for_vm)
      if [ -z "''${pids:-}" ]; then
        return 0
      fi
      # Take first PID (usually one instance)
      pid=$(echo "$pids" | head -1)
      port=$(spice_port_of_pid "$pid" || true)
      if [ "''${REPLACE_EXISTING:-0}" = "1" ]; then
        stop_running_vm
        return 0
      fi
      print_running_vm_help "$pid" "$port"
      exit 0
    }

    function report_disk_lock_failure() {
      local pids pid port
      echo "❌ Disk is locked: ${image.path}" >&2
      pids=$(qemu_pids_for_vm)
      if [ -n "''${pids:-}" ]; then
        pid=$(echo "$pids" | head -1)
        port=$(spice_port_of_pid "$pid" || true)
        print_running_vm_help "$pid" "$port" >&2
      else
        echo "  No QEMU with -name ${name} found, but the qcow2 is locked." >&2
        echo "  Find holder:  lsof ${image.path}" >&2
        echo "  Or:           pgrep -af qemu-system" >&2
      fi
      exit 1
    }

    ${lib.optionalString isWindows ''
    function prepare_tpm() {
      echo "🔐 Preparing software TPM (required for Windows)..."
      mkdir -p "$SWTPM_DIR"
      rm -f "$SWTPM_DIR/swtpm-sock" 2>/dev/null || true
      # Kill stale swtpm for this VM if still running
      pkill -f "swtpm.*''${SWTPM_DIR}" 2>/dev/null || true
      sleep 0.1
      ${pkgs.swtpm}/bin/swtpm socket \
        --tpmstate dir="$SWTPM_DIR" \
        --ctrl type=unixio,path="$SWTPM_DIR/swtpm-sock" \
        --tpm2 \
        --daemon
      # Give swtpm a moment to create the socket
      for i in 1 2 3 4 5; do
        if [ -S "$SWTPM_DIR/swtpm-sock" ]; then
          break
        fi
        sleep 0.2
      done
      if [ ! -S "$SWTPM_DIR/swtpm-sock" ]; then
        echo "❌ swtpm socket was not created at $SWTPM_DIR/swtpm-sock" >&2
        exit 1
      fi
    }
    ''}

    # After installer reboot: if disk looks installed, detach CD so UEFI boots disk
    # (same QEMU session — no need to quit and re-run ncc).
    function start_iso_eject_on_reset() {
      local qmp_sock="$1"
      local disk_path="$2"
      ${pkgs.python3}/bin/python3 - "$qmp_sock" "$disk_path" ${pkgs.qemu}/bin/qemu-img <<'PY'
import json, os, socket, subprocess, sys, time

qmp_sock, disk_path, qemu_img = sys.argv[1:4]
threshold = 67108864  # 64 MiB allocated

def disk_installed() -> bool:
    if not os.path.isfile(disk_path):
        return False
    try:
        raw = subprocess.check_output(
            [qemu_img, "info", "--output=json", disk_path],
            stderr=subprocess.DEVNULL,
            text=True,
        )
        info = json.loads(raw)
        return int(info.get("actual-size") or 0) > threshold
    except Exception:
        return False

def connect():
    deadline = time.time() + 30
    while time.time() < deadline:
        if os.path.exists(qmp_sock):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(qmp_sock)
                return s
            except OSError:
                pass
        time.sleep(0.1)
    return None

sock = connect()
if sock is None:
    sys.exit(0)
sock.settimeout(None)
buf = b""

def recv_msg():
    global buf
    while True:
        if b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            line = line.strip()
            if line:
                return json.loads(line)
        chunk = sock.recv(4096)
        if not chunk:
            return None
        buf += chunk

def send(cmd):
    sock.sendall((json.dumps(cmd) + "\n").encode())
    return recv_msg()

# Greeting + negotiate
if recv_msg() is None:
    sys.exit(0)
send({"execute": "qmp_capabilities"})

while True:
    msg = recv_msg()
    if msg is None:
        break
    if msg.get("event") != "RESET":
        continue
    if not disk_installed():
        continue
    # Drop CD from the machine so the next boot uses the disk
    send({"execute": "device_del", "arguments": {"id": "cdrom0"}})
    print("💿 Installer reboot detected — ISO detached, next boot from disk", flush=True)
    break
sock.close()
PY
    }

    function start_vm() {
      local iso_path="''${1:-}"
      local boot_mode="''${2:-iso}"  # iso | disk

      # Get free port and store it
      local spice_port
      spice_port=$(${portManager.vmPortManager name})
      local runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}/ncc-vm/${name}"
      mkdir -p "$runtime_dir"
      local qmp_sock="$runtime_dir/qmp.sock"
      local eject_helper_pid=""
      
      echo "🚀 Starting VM..."
      echo "  Name: ${name}"
      echo "  Distro: ${distroName}"
      echo "  Boot: $boot_mode"
      echo "  Memory: ${toString memory}MB"
      echo "  Cores: ${toString cores}"
      echo "  SPICE Display: spice://localhost:$spice_port"
      echo ""
      echo "💡 To connect: remote-viewer spice://localhost:$spice_port"
      echo "              (or: spicy -h localhost -p $spice_port)"
      if [ "$boot_mode" = "iso" ]; then
        echo "💡 After install: reboot in the guest → boots installed OS (same session)"
        echo "💡 Force installer anytime: ncc vm test-${distro}-run --iso"
        echo "💡 Force disk boot:         ncc vm test-${distro}-run --disk"
      fi
      echo "⏳ Starting QEMU (this might take a moment)..."
      echo ""

      if [ "$boot_mode" = "iso" ] && { [ -z "$iso_path" ] || [ ! -f "$iso_path" ]; }; then
        echo "❌ Error: ISO file not found!"
        exit 1
      fi
      if [ "$boot_mode" = "disk" ] && [ ! -f "${image.path}" ]; then
        echo "❌ No disk image yet: ${image.path}" >&2
        echo "   Install first: ncc vm test-${distro}-run" >&2
        exit 1
      fi

      if [ ! -e /dev/kvm ]; then
        echo "❌ /dev/kvm missing — KVM kernel module not loaded" >&2
        echo "   After enabling the VM module, rebuild+switch should load kvm-intel/kvm-amd." >&2
        echo "   If this persists after rebuild, VT-x/AMD-V may be disabled in firmware." >&2
        exit 1
      fi
      if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
        echo "❌ /dev/kvm not accessible — user must be in group 'kvm' (re-login after rebuild)" >&2
        exit 1
      fi

      # Drive args: ISO boot prefers CD (bootindex=1); disk boot boots installed system only.
      # cdrom0 id is required so QMP can detach the ISO after post-install RESET.
      local drive_args
      local qmp_args=()
      if [ "$boot_mode" = "disk" ]; then
        ${if isWindows then ''
        drive_args=(
          -device ahci,id=ahci0
          -drive if=none,id=disk0,file="${image.path}",format=qcow2
          -device ide-hd,bus=ahci0.0,drive=disk0,bootindex=1
        )
        '' else ''
        drive_args=(
          -drive if=none,id=disk0,file="${image.path}",format=qcow2
          -device virtio-blk-pci,drive=disk0,bootindex=1
        )
        ''}
      else
        ${if isWindows then ''
        drive_args=(
          -device ahci,id=ahci0
          -drive if=none,id=disk0,file="${image.path}",format=qcow2
          -device ide-hd,bus=ahci0.0,drive=disk0,bootindex=2
          -drive if=none,id=cd0,media=cdrom,readonly=on,file="$iso_path"
          -device ide-cd,id=cdrom0,bus=ahci0.1,drive=cd0,bootindex=1
        )
        '' else ''
        drive_args=(
          -drive if=none,id=disk0,file="${image.path}",format=qcow2
          -device virtio-blk-pci,drive=disk0,bootindex=2
          -device ahci,id=ahci0
          -drive if=none,id=cd0,media=cdrom,readonly=on,file="$iso_path"
          -device ide-cd,id=cdrom0,bus=ahci0.0,drive=cd0,bootindex=1
        )
        ''}
        rm -f "$qmp_sock"
        qmp_args=( -qmp "unix:$qmp_sock,server,nowait" )
        start_iso_eject_on_reset "$qmp_sock" "${image.path}" &
        eject_helper_pid=$!
      fi

      # q35 IDE buses only allow 1 unit each — use a dedicated AHCI controller
      # for disk+ISO with bootindex (OVMF ignores classic -boot order= / -cdrom).
      set +e
      qemu_err=$(mktemp /tmp/ncc-qemu-XXXXXX.err)
      ${pkgs.qemu}/bin/qemu-system-x86_64 \
        -name "${name}" \
        -enable-kvm \
        -m ${toString memory} \
        -smp ${toString cores} \
        -cpu host \
        ${if needsSecureBoot then ''
        -machine q35,accel=kvm,smm=on \
        -global driver=cfi.pflash01,property=secure,value=on \
        '' else ''
        -machine q35,accel=kvm \
        ''} \
        -drive if=pflash,format=raw,readonly=on,file=${ovmfCode} \
        -drive if=pflash,format=raw,file="${vars_path}" \
        ${if isWindows then ''
        -chardev socket,id=chrtpm,path="$SWTPM_DIR/swtpm-sock" \
        -tpmdev emulator,id=tpm0,chardev=chrtpm \
        -device tpm-tis,tpmdev=tpm0 \
        '' else ""} \
        "''${drive_args[@]}" \
        "''${qmp_args[@]}" \
        -vga qxl \
        -spice port="$spice_port",disable-ticketing=on \
        -device virtio-tablet-pci \
        -device virtio-keyboard-pci \
        ${if isWindows then ''
        # e1000: in-box Windows driver (virtio-net needs virtio-win ISO)
        -device e1000,netdev=net0 \
        '' else ''
        -device virtio-net-pci,netdev=net0 \
        ''} \
        -netdev user,id=net0 \
        -boot menu=on 2>"$qemu_err"
      qemu_rc=$?
      set -e
      if [ -n "$eject_helper_pid" ]; then
        kill "$eject_helper_pid" 2>/dev/null || true
        wait "$eject_helper_pid" 2>/dev/null || true
      fi
      rm -f "$qmp_sock"
      if [ "$qemu_rc" -ne 0 ]; then
        cat "$qemu_err" >&2 || true
        if grep -qiE 'Failed to get "write" lock|Is another process using the image' "$qemu_err" 2>/dev/null; then
          rm -f "$qemu_err"
          report_disk_lock_failure
        fi
        rm -f "$qemu_err"
        exit "$qemu_rc"
      fi
      rm -f "$qemu_err"
    }


    # Main
    # Boot mode: auto (default) | iso | disk
    # Auto: empty/fresh qcow2 → installer ISO; disk with real data → boot installed OS
    # Override: --disk / --iso  or  VM_BOOT=disk|iso
    # --replace / --restart: kill existing QEMU for this VM first
    boot_mode="''${VM_BOOT:-auto}"
    REPLACE_EXISTING=0
    for arg in "$@"; do
      case "$arg" in
        --disk|--installed|--from-disk) boot_mode=disk ;;
        --iso|--installer) boot_mode=iso ;;
        --auto) boot_mode=auto ;;
        --replace|--restart|--force-restart) REPLACE_EXISTING=1 ;;
        -h|--help)
          echo "Usage: ncc vm test-${distro}-run [--auto|--disk|--iso] [--replace]"
          echo "  (default)  Auto: installer if disk empty, else boot installed OS"
          echo "  --disk     Force boot from disk (no ISO)"
          echo "  --iso      Force installer ISO boot (after install, guest reboot → disk)"
          echo "  --auto     Same as default"
          echo "  --replace  Kill existing QEMU for this VM, then start"
          exit 0
          ;;
      esac
    done

    # Bare-QEMU VMs are not libvirt domains — detect by -name before allocating ports
    ensure_no_conflicting_vm

    echo "🖥️  ${distroName} Test VM Setup"
    echo "========================"
    prepare_dirs
    prepare_ovmf
    create_disk
    ${lib.optionalString isWindows "prepare_tpm"}

    # Detect install state via allocated qcow2 size (fresh image is ~200KB; install writes GBs)
    disk_looks_installed() {
      local disk="${image.path}"
      local actual=0
      [[ -f "$disk" ]] || return 1
      actual=$(${pkgs.qemu}/bin/qemu-img info --output=json "$disk" 2>/dev/null \
        | ${pkgs.jq}/bin/jq -r '."actual-size" // 0' 2>/dev/null || echo 0)
      # 64 MiB threshold — empty sparse qcow2 stays far below this
      [[ "''${actual:-0}" -gt 67108864 ]]
    }

    if [ "$boot_mode" = "auto" ]; then
      if disk_looks_installed; then
        boot_mode=disk
        echo "✓ Disk looks installed → booting from disk"
      else
        boot_mode=iso
        echo "○ Disk empty/fresh → booting installer ISO"
      fi
    fi

    if [ "$boot_mode" = "disk" ]; then
      echo "💾 Booting from installed disk (no ISO)..."
      start_vm "" disk
    else
      echo "💿 Checking ISO..."
      echo "Debug: Distro = ${distro}"
      echo "Debug: Version = ${versionString}"
      ${if localOnly then ''
      echo "Debug: Local ISO only (no auto-download)"
      '' else ''
      echo "Debug: URL = ${toString isoUrl}"
      ''}
      
      iso_path="$(${isoManager.isoManager {
        name = "${distro}-${name}";
        inherit stateDir;
        url = toString isoUrl;
        distroName = distroName;
        inherit variant;
        version = versionString;
        inherit localOnly;
        inherit isoHint;
      }})"
      
      echo "Debug: ISO path = $iso_path"
      
      if [ -z "$iso_path" ] || [ ! -f "$iso_path" ]; then
        echo "❌ ISO management failed!"
        exit 1
      fi
      start_vm "$iso_path" iso
    fi
  '';
}
