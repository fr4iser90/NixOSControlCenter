{ lib, getModuleApi, ... }:

let
  ui = getModuleApi "cli-formatter";
in
{
  bootEntriesPath = "/boot/loader/entries";
  validatePermissions = ''
    if [ "$(id -u)" != "0" ] && ! groups | grep -qw "wheel"; then
      ${ui.messages.error "This script requires root or wheel group permissions"}
      exit 1
    fi
  '';
}
