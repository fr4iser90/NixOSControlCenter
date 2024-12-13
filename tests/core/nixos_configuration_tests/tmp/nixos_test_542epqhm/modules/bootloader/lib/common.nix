{ lib, ... }:
{
  bootEntriesPath = "/boot/loader/entries";
  validatePermissions = ''
    if [ "$(id -u)" != "0" ] && ! groups | grep -qw "wheel"; then
      echo "Error: This script requires root or wheel group permissions"
      exit 1
    fi
  '';
}
