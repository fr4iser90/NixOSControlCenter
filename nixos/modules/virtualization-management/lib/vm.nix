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
      if [ ! -f "${vars_path}" ]; then
        install -Dm644 ${ovmf.fd}/FV/OVMF_VARS.fd "${vars_path}"
      fi
    }

    function download_iso() {
      local iso_dir="/var/lib/virt/testing/iso"
      local iso_name="${distro}-${variant}-${versionString}.iso"
      local iso_path="$iso_dir/$iso_name"
      
      mkdir -p "$iso_dir"
      if [ ! -f "$iso_path" ]; then
        echo "Downloading ${distros.distros.${distro}.name} ${versionString} (${distros.distros.${distro}.variants.${variant}.name})..."
        wget -O "$iso_path" "${isoUrl}"
      fi
      echo "$iso_path"
    }

    function create_disk() {
      if [ ! -f "${image.path}" ]; then
        echo "Creating new VM image (${toString image.size}GB)..."
        mkdir -p "$(dirname "${image.path}")"
        ${pkgs.qemu}/bin/qemu-img create -f qcow2 "${image.path}" ${toString image.size}G
        chown root:libvirt "${image.path}"
        chmod 664 "${image.path}"
      fi
    }

    function start_vm() {
      local iso_path="$1"
      local qemu_args=()

      if [ -n "$iso_path" ]; then
        qemu_args+=("-cdrom" "$iso_path")
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
        "''${qemu_args[@]}"
    }
  '';
}