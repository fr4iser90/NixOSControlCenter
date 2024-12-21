{ lib, pkgs }:

let
  distros = import ./distros.nix { inherit lib; };
in
{
  inherit (distros) distros validateDistro getDistroUrl;

  mkVmScript = { name, memory, cores, image, distro ? "nixos", variant ? "plasma5", version ? null, ovmf ? pkgs.OVMF }: let
    vars_path = "/var/lib/virt/testing/vars/${name}_VARS.fd";
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

    function download_iso() {
      local iso_dir="/var/lib/virt/testing/iso"
      local iso_name="${distro}-${variant}-${versionString}.iso"
      local iso_path="$iso_dir/$iso_name"
      
      mkdir -p "$iso_dir"
      
      if [ ! -f "$iso_path" ]; then
        echo "  Downloading ${distros.distros.${distro}.name} ${versionString}"
        echo "  Variant: ${distros.distros.${distro}.variants.${variant}.name}"
        echo "  URL: ${isoUrl}"
        echo "  This might take a while..."
        wget -O "$iso_path" "${isoUrl}"
        echo "  Download complete!"
      fi
      
      # Prüfe ob die Datei existiert
      if [ -f "$iso_path" ]; then
        echo "$iso_path"
        return 0
      else
        echo ""
        return 1
      fi
    }

    function create_disk() {
      echo "💾 Checking VM disk..."
      if [ ! -f "${image.path}" ]; then
        echo "  Creating new ${toString image.size}GB disk..."
        mkdir -p "$(dirname "${image.path}")"
        ${pkgs.qemu}/bin/qemu-img create -f qcow2 "${image.path}" ${toString image.size}G
        chown root:libvirt "${image.path}"
        chmod 664 "${image.path}"
        echo "  Disk created!"
      else
        echo "  Using existing disk"
      fi
    }

    function start_vm() {
      local iso_path="$1"
      local qemu_args=()

      echo "🚀 Starting VM..."
      echo "  Name: ${name}"
      echo "  Memory: ${toString memory}MB"
      echo "  Cores: ${toString cores}"
      echo "  SPICE Display: spice://localhost:5900"
      echo ""
      echo "💡 To connect: virt-viewer --connect spice://localhost:5900"
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
        -machine q35,accel=kvm \
        -drive if=pflash,format=raw,readonly=on,file=${ovmf.fd}/FV/OVMF_CODE.fd \
        -drive if=pflash,format=raw,file="${vars_path}" \
        -vga qxl \
        -spice port=5900,disable-ticketing=on \
        -device virtio-tablet-pci \
        -device virtio-keyboard-pci \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0 \
        -drive file="${image.path}",if=virtio \
        -boot order=dc \
        ''${qemu_args[@]+"''${qemu_args[@]}"}
    }

    # Main
    echo "🖥️  NixOS Test VM Setup"
    echo "========================"
    prepare_ovmf
    create_disk
    echo "💿 Checking ISO..."
    iso_path=$(download_iso)
    start_vm "$iso_path"
  '';
}