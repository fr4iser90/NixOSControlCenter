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
    variant ? "plasma5",
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

    function start_vm() {
      local iso_path="$1"

      # Get free port and store it
      local spice_port
      spice_port=$(${portManager.vmPortManager name})
      
      echo "🚀 Starting VM..."
      echo "  Name: ${name}"
      echo "  Distro: ${distroName}"
      echo "  Memory: ${toString memory}MB"
      echo "  Cores: ${toString cores}"
      echo "  SPICE Display: spice://localhost:$spice_port"
      echo ""
      echo "💡 To connect: virt-viewer --connect spice://localhost:$spice_port"
      echo "⏳ Starting QEMU (this might take a moment)..."
      echo ""

      if [ -z "$iso_path" ] || [ ! -f "$iso_path" ]; then
        echo "❌ Error: ISO file not found!"
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

      # q35 IDE buses only allow 1 unit each — use a dedicated AHCI controller
      # for disk+ISO with bootindex (OVMF ignores classic -boot order= / -cdrom).
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
        -device ahci,id=ahci0 \
        -drive if=none,id=disk0,file="${image.path}",format=qcow2 \
        -device ide-hd,bus=ahci0.0,drive=disk0,bootindex=2 \
        -drive if=none,id=cd0,media=cdrom,readonly=on,file="$iso_path" \
        -device ide-cd,bus=ahci0.1,drive=cd0,bootindex=1 \
        '' else ''
        -drive if=none,id=disk0,file="${image.path}",format=qcow2 \
        -device virtio-blk-pci,drive=disk0,bootindex=2 \
        -device ahci,id=ahci0 \
        -drive if=none,id=cd0,media=cdrom,readonly=on,file="$iso_path" \
        -device ide-cd,bus=ahci0.0,drive=cd0,bootindex=1 \
        ''} \
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
        -boot menu=on
    }


    # Main
    echo "🖥️  ${distroName} Test VM Setup"
    echo "========================"
    prepare_dirs
    prepare_ovmf
    create_disk
    ${lib.optionalString isWindows "prepare_tpm"}
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
    start_vm "$iso_path"
  '';
}
