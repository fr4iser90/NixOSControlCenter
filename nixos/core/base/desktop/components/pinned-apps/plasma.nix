{ config, lib, pkgs, getModuleConfig, ... }:

let
  desktopCfg = getModuleConfig "desktop";
  packagesCfg = getModuleConfig "packages";
  userCfg = getModuleConfig "user";

  pinMap = import ../../lib/pin-map.nix;
  resolvePins = import ../../lib/resolve-pins.nix { inherit lib pinMap; };

  userPackagesFlat = lib.unique (lib.concatLists (
    lib.attrValues (packagesCfg.userPackages or {})
  ));

  pins = resolvePins {
    pinnedApps = desktopCfg.pinnedApps or [];
    pinnedAppsAuto = desktopCfg.pinnedAppsAuto or true;
    packageModules = packagesCfg.packageModules or [];
    systemPackages = packagesCfg.systemPackages or [];
    inherit userPackagesFlat;
    environment = desktopCfg.environment or "plasma";
  };

  force = desktopCfg.pinnedAppsForce or false;

  userNames = lib.filter (name:
    let u = userCfg.${name} or null;
    in builtins.isAttrs u && u ? role
  ) (lib.attrNames userCfg);

  pinsJson = builtins.toJSON pins;
  forceFlag = if force then "1" else "0";

  qdbusBin =
    if pkgs ? kdePackages && pkgs.kdePackages ? qttools
    then "${pkgs.kdePackages.qttools}/bin/qdbus"
    else "${pkgs.qt6.qttools}/bin/qdbus";

  pinScript = pkgs.writeShellScriptBin "ncc-pin-plasma-apps" ''
    set -euo pipefail

    MARKER_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/ncc"
    MARKER="$MARKER_DIR/pinned-apps-applied"
    FORCE="${forceFlag}"
    PINS='${pinsJson}'

    if [ -z "$PINS" ] || [ "$PINS" = "[]" ]; then
      exit 0
    fi

    # Once-apply: rebuilds must not clobber user taskbar edits
    if [ "$FORCE" != "1" ] && [ -f "$MARKER" ]; then
      exit 0
    fi

    for _ in $(seq 1 90); do
      if ${pkgs.procps}/bin/pgrep -u "$USER" plasmashell >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    if ! ${pkgs.procps}/bin/pgrep -u "$USER" plasmashell >/dev/null 2>&1; then
      echo "ncc-pin-plasma-apps: plasmashell not running, skip" >&2
      exit 0
    fi

    # Panel widgets need a moment after plasmashell starts
    sleep 3

    LAUNCHERS=$(${pkgs.jq}/bin/jq -r 'map("applications:" + .) | @json' <<<"$PINS")

    SCRIPT=$(cat <<EOF
var launchers = $LAUNCHERS;
var panels = panels();
for (var i = 0; i < panels.length; i++) {
  var widgets = panels[i].widgets();
  for (var j = 0; j < widgets.length; j++) {
    var t = widgets[j].type;
    if (t === "org.kde.plasma.icontasks" || t === "org.kde.plasma.taskmanager") {
      widgets[j].currentConfigGroup = ["General"];
      widgets[j].writeConfig("launchers", launchers);
      widgets[j].reloadConfig();
    }
  }
}
EOF
)

    ${qdbusBin} org.kde.plasmashell /PlasmaShell \
      org.kde.PlasmaShell.evaluateScript "$SCRIPT" >/dev/null 2>&1 || true

    mkdir -p "$MARKER_DIR"
    {
      echo "applied=$(date -Iseconds)"
      echo "pins=$PINS"
    } > "$MARKER"
  '';

  hmUser = {
    home.packages = [ pinScript ];
    xdg.configFile."autostart/ncc-pin-plasma-apps.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=NCC Pin Taskbar Apps
      Comment=Apply NCC default taskbar pins once (skips if already applied)
      Exec=${pinScript}/bin/ncc-pin-plasma-apps
      X-KDE-autostart-phase=2
      OnlyShowIn=KDE;
      X-GNOME-Autostart-enabled=false
      NoDisplay=true
    '';
  };
in
lib.mkIf (pins != [] && userNames != []) {
  home-manager.users = lib.genAttrs userNames (_: hmUser);
}
