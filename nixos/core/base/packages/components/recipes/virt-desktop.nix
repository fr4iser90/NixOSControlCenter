{
  description = "Desktop virtualization GUI (qemu-vm + virt-manager)";
  systemTypes = [ "desktop" ];
  scope = "system";
  modules = [
    "qemu-vm"
    "virt-manager"
  ];
}
