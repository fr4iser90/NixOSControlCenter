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
    vars_path = "${stateDir}/testing/vars/${name}_VARS.fd";
    swtpm_dir = "${stateDir}/testing/swtpm/${name}";
    validVersion = distros.validateDistro distro variant version;
    localOnly = distros.isLocalIso distro variant;
    osFamily = distros.getOsFamily distro;
    isoHint = distros.getIsoHint distro variant;
    isoUrl = if localOnly then "" else distros.getDistroUrl distro variant validVersion;
    versionString = if validVersion == null then "latest" else validVersion;
    distroName = distros.distros.${distro}.name;
    isWindows = osFamily == "windows";
  in ''
    function prepare_dirs() {
      for d in \
        "${stateDir}/testing" \
        "${stateDir}/testing/vars" \
        "${stateDir}/testing/iso" \
        "${stateDir}/testing/images" \
        "${stateDir}/testing/swtpm"
      do
        if [ ! -d "$d" ]; then
          mkdir -p "$d" 2>/dev/null || sudo mkdir -p "$d"
        fi
      done
    }

    function prepare_ovmf() {
      echo "🔧 Preparing OVMF VARS..."
      if [ ! -f "${vars_path}" ]; then
        echo "  Creating new VARS file..."
        install -Dm644 ${ovmf.fd}/FV/OVMF_VARS.fd "${vars_path}" 2>/dev/null \
          || sudo install -Dm644 ${ovmf.fd}/FV/OVMF_VARS.fd "${vars_path}"
        if getent group libvirtd >/dev/null 2>&1; then
          chown "$USER:libvirtd" "${vars_path}" 2>/dev/null \
            || sudo chown "$USER:libvirtd" "${vars_path}" 2>/dev/null || true
        fi
        chmod 664 "${vars_path}" 2>/dev/null || sudo chmod 664 "${vars_path}" || true
      else
        echo "  Using existing VARS file"
      fi
    }

    function create_disk() {
      echo "💾 Checking VM disk..."
      if [ ! -f "${image.path}" ]; then
        echo "  Creating new ${toString image.size}GB disk..."
        mkdir -p "$(dirname "${image.path}")" 2>/dev/null \
          || sudo mkdir -p "$(dirname "${image.path}")"
        ${pkgs.qemu}/bin/qemu-img create -f qcow2 "${image.path}" ${toString image.size}G \
          || sudo ${pkgs.qemu}/bin/qemu-img create -f qcow2 "${image.path}" ${toString image.size}G

        if getent group libvirtd > /dev/null; then
          chown "$USER:libvirtd" "${image.path}" 2>/dev/null \
            || sudo chown "$USER:libvirtd" "${image.path}" 2>/dev/null || true
        else
          chown "$USER:kvm" "${image.path}" 2>/dev/null \
            || sudo chown "$USER:kvm" "${image.path}" 2>/dev/null || true
        fi

        chmod 664 "${image.path}" 2>/dev/null || sudo chmod 664 "${image.path}" || true
        echo "  Disk created!"
      else
        echo "  Using existing disk"
      fi
    }

    ${lib.optionalString isWindows ''
    function prepare_tpm() {
      echo "🔐 Preparing software TPM (required for Windows)..."
      mkdir -p "${swtpm_dir}" 2>/dev/null || sudo mkdir -p "${swtpm_dir}"
      # Stop stale emulator if present
      if [ -S "${swtpm_dir}/swtpm-sock" ]; then
        rm -f "${swtpm_dir}/swtpm-sock" 2>/dev/null || true
      fi
      ${pkgs.swtpm}/bin/swtpm socket \
        --tpmstate dir="${swtpm_dir}" \
        --ctrl type=unixio,path="${swtpm_dir}/swtpm-sock" \
        --tpm2 \
        --daemon
      # Give swtpm a moment to create the socket
      sleep 0.3
    }
    ''}

    function start_vm() {
      local iso_path="$1"
      local qemu_args=()

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

      if [ -n "$iso_path" ] && [ -f "$iso_path" ]; then
        qemu_args+=("-cdrom" "$iso_path")
      else
        echo "❌ Error: ISO file not found!"
        exit 1
      fi

      ${pkgs.qemu}/bin/qemu-system-x86_64 \
        -name "${name}" \
        -enable-kvm \
        -m ${toString memory} \
        -smp ${toString cores} \
        -cpu host \
        -machine q35,accel=kvm,smm=on \
        -global driver=cfi.pflash01,property=secure,value=on \
        -drive if=pflash,format=raw,readonly=on,file=${ovmf.fd}/FV/OVMF_CODE.fd \
        -drive if=pflash,format=raw,file="${vars_path}" \
        ${if isWindows then ''
        -chardev socket,id=chrtpm,path="${swtpm_dir}/swtpm-sock" \
        -tpmdev emulator,id=tpm0,chardev=chrtpm \
        -device tpm-tis,tpmdev=tpm0 \
        -drive file="${image.path}",if=ide,format=qcow2 \
        '' else ''
        -drive file="${image.path}",if=virtio \
        ''} \
        -vga qxl \
        -spice port="$spice_port",disable-ticketing=on \
        -device virtio-tablet-pci \
        -device virtio-keyboard-pci \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0 \
        -boot order=dc,menu=on \
        ''${qemu_args[@]+"''${qemu_args[@]}"}
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
