# Launcher-worthy apps only — keep this list small.
# Keys: nixpkgs attr OR packageModule name → list of .desktop IDs
{
  packages = {
    firefox = [ "firefox.desktop" ];
    chromium = [ "chromium-browser.desktop" ];
    brave = [ "brave-browser.desktop" ];
    librewolf = [ "librewolf.desktop" ];
    vscode = [ "code.desktop" ];
    vscodium = [ "codium.desktop" ];
  };

  modules = {
    gaming = [
      "steam.desktop"
      "vesktop.desktop"
      "com.heroicgameslauncher.hgl.desktop"
    ];
    streaming = [ "com.obsproject.Studio.desktop" ];
    web-dev = [ "code.desktop" ];
  };

  # DE-specific extras when auto-pinning (only if that DE is active)
  defaultsByEnv = {
    plasma = [ "org.kde.dolphin.desktop" "org.kde.konsole.desktop" ];
    gnome = [ "org.gnome.Nautilus.desktop" "org.gnome.Terminal.desktop" ];
    xfce = [ "thunar.desktop" "xfce4-terminal.desktop" ];
  };
}
