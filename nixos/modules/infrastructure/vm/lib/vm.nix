{ lib, pkgs }:

let
  distros = import ./distros.nix { inherit lib; };
  portManager = import ./port-manager.nix { inherit lib pkgs; };
  isoManager = import ./iso-manager.nix { inherit lib pkgs; };
in
{
  inherit (distros) distros validateDistro getDistroUrl;

  mkVmScript = { name, memory, cores, image, distro ? "nixos", variant ? "plasma5", version ? null, stateDir ? "/var/lib/virt", ovmf ? pkgs.OVMF }: let
    vars_path = "${stateDir}/testing/vars/${name}_VARS.fd";
    validVersion = distros.validateDistro distro variant version;
    isoUrl = distros.getDistroUrl distro variant validVersion;
    versionString = if validVersion == null then "latest" else validVersion;
  in ''
    function prepare_ovmf() {
      echo "🔧 Preparing OVMF VARS..."
      if [ ! -f "${vars_path}" ]; then
        echo "  Creating new VARS file..."
        install -Dm644 ${ovmf.fd}/FV/OVMF_VARS.fd "${vars_path}"
      else
        echo "  Using existing VARS file"
      fi
    }

    function create_disk() {
      echo "💾 Checking VM disk..."
      if [ ! -f "${image.path}" ]; then
        echo "  Creating new ${toString image.size}GB disk..."
        mkdir -p "$(dirname "${image.path}")"
        ${pkgs.qemu}/bin/qemu-img create -f qcow2 "${image.path}" ${toString image.size}G
        
        # Setze Berechtigungen basierend auf existierenden Gruppen
        if getent group libvirtd > /dev/null; then
          chown $USER:libvirtd "${image.path}"
        else
          chown $USER:kvm "${image.path}"
        fi
        
        chmod 664 "${image.path}"
        echo "  Disk created!"
      else
        echo "  Using existing disk"
      fi
    }

    function start_vm() {
      local iso_path="$1"
      local qemu_args=()

      # Get free port and store it
      local spice_port
      spice_port=$(${portManager.vmPortManager name})
      
      echo "🚀 Starting VM..."
      echo "  Name: ${name}"
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
        -vga qxl \
        -spice port="$spice_port",disable-ticketing=on \
        -device virtio-tablet-pci \
        -device virtio-keyboard-pci \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0 \
        -drive file="${image.path}",if=virtio \
        -boot order=dc,menu=on \
        ''${qemu_args[@]+"''${qemu_args[@]}"}
    }


    # Main
    echo "🖥️  NixOS Test VM Setup"
    echo "========================"
    prepare_ovmf
    create_disk
    echo "💿 Checking ISO..."
    echo "Debug: Distro = ${distro}"
    echo "Debug: Version = ${versionString}"
    echo "Debug: URL = ${isoUrl}"
    
    iso_path="$(${isoManager.isoManager {
      name = "${distro}-${name}";
      inherit stateDir;
      url = "${toString isoUrl}";
      distroName = distros.distros.${distro}.name;
      inherit variant;
      version = versionString;
    }})"
    
    echo "Debug: ISO path = $iso_path"
    
    if [ $? -ne 0 ]; then
      echo "❌ ISO management failed!"
      exit 1
    fi
    start_vm "$iso_path"
  '';
}