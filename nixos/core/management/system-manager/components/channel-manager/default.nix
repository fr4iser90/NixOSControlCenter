{ pkgs, lib, getModuleApi, hostname, systemChecks, channel, onCalendar }:

let
  updateModule = import ./update-channels.nix {
    inherit pkgs lib getModuleApi hostname systemChecks;
  };
  checkModule = import ./check-release.nix {
    inherit pkgs lib getModuleApi channel;
  };
  notifyModule = import ./notify.nix {
    inherit pkgs lib onCalendar;
    checkReleaseScript = checkModule.checkReleaseScript;
  };
in {
  updateChannelsScript = updateModule.updateChannelsScript;
  checkReleaseScript = checkModule.checkReleaseScript;
  notifyScript = notifyModule.notifyScript;
  notifyNixosConfig = notifyModule.nixosConfig;
}
