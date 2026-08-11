# Curated product-name → Store install map (individual apps).
# Consumed by mk-catalog-json.nix (JSON) and ncc-packages CLI + GUI.
#
# Store policy: intents here are apps (kind=attr) or rare guided tips (kind=guided).
# Sets / recipes / user-presets live in components/{sets,recipes,user-presets}
# and the "Recipes & sets" GUI tab — not in the Store catalog.
#
# kind:
#   attr    → ncc packages add <attr>  (userPackages)
#   guided  → explain only; point user to Recipes & sets (no blind module add)
#
# Optional partOfSet: name of a system set that also includes this app (UX hint).

{
  categories = [
    { id = "browsers"; title = "Browsers"; description = "Web browsers"; }
    { id = "chat"; title = "Chat and social"; description = "Messaging and Discord-class apps"; }
    { id = "dev"; title = "Development"; description = "Editors, IDEs, language toolchains"; }
    { id = "games"; title = "Games"; description = "Steam, launchers, related tools"; }
    { id = "creative"; title = "Creative"; description = "Image, video, 3D"; }
    { id = "office"; title = "Office and docs"; description = "Documents and notes"; }
    { id = "media"; title = "Media"; description = "Players, recording, music"; }
    { id = "system"; title = "System tools"; description = "CLI utilities"; }
  ];

  intents = [
    # ── Browsers ──────────────────────────────────────────────────────────
    {
      id = "firefox";
      title = "Firefox";
      aliases = [ "firefox" "mozilla" ];
      description = "Mozilla Firefox web browser";
      category = "browsers";
      kind = "attr";
      scope = "user";
      attr = "firefox";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "chromium" ];
      notes = "Adds to your userPackages.";
    }
    {
      id = "chromium";
      title = "Chromium";
      aliases = [ "chromium" "chrome" "google chrome" ];
      description = "Chromium browser (open-source Chrome)";
      category = "browsers";
      kind = "attr";
      scope = "user";
      attr = "chromium";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "firefox" ];
      notes = "Adds to your userPackages.";
    }
    {
      id = "brave";
      title = "Brave";
      aliases = [ "brave" "brave browser" ];
      description = "Brave browser";
      category = "browsers";
      kind = "attr";
      scope = "user";
      attr = "brave";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = true;
      related = [ "firefox" "chromium" ];
      notes = "Unfree; ensure allowUnfree is enabled.";
    }

    # ── Chat ──────────────────────────────────────────────────────────────
    {
      id = "discord";
      title = "Discord";
      aliases = [ "discord" ];
      description = "Discord client (vesktop is in the gaming set)";
      category = "chat";
      kind = "attr";
      scope = "user";
      attr = "discord";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = true;
      related = [ "signal-desktop" "telegram-desktop" ];
      notes = "Unfree. The gaming set installs vesktop instead.";
    }
    {
      id = "signal-desktop";
      title = "Signal";
      aliases = [ "signal" "signal desktop" ];
      description = "Signal Desktop";
      category = "chat";
      kind = "attr";
      scope = "user";
      attr = "signal-desktop";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "telegram-desktop" ];
      notes = "Adds to your userPackages.";
    }
    {
      id = "telegram-desktop";
      title = "Telegram";
      aliases = [ "telegram" "telegram desktop" ];
      description = "Telegram Desktop";
      category = "chat";
      kind = "attr";
      scope = "user";
      attr = "telegram-desktop";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "signal-desktop" ];
      notes = "Adds to your userPackages.";
    }

    # ── Development ───────────────────────────────────────────────────────
    {
      id = "vscode";
      title = "VS Code";
      aliases = [ "vscode" "code" "vs code" "visual studio code" ];
      description = "Visual Studio Code";
      category = "dev";
      kind = "attr";
      scope = "user";
      attr = "vscode";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = true;
      related = [ "cursor" "vscodium" ];
      notes = "Unfree; ensure allowUnfree is enabled.";
    }
    {
      id = "vscodium";
      title = "VSCodium";
      aliases = [ "vscodium" "codium" ];
      description = "Open-source VS Code build";
      category = "dev";
      kind = "attr";
      scope = "user";
      attr = "vscodium";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "vscode" ];
      notes = "Adds to your userPackages.";
    }
    {
      id = "cursor";
      title = "Cursor";
      aliases = [ "cursor" "cursor editor" "cursor ide" ];
      description = "Cursor AI editor";
      category = "dev";
      kind = "attr";
      scope = "user";
      attr = "code-cursor";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = true;
      related = [ "vscode" ];
      notes = "Attr is code-cursor. Unfree; ensure allowUnfree is enabled.";
    }
    {
      id = "neovim";
      title = "Neovim";
      aliases = [ "neovim" "nvim" "vim" ];
      description = "Neovim editor";
      category = "dev";
      kind = "attr";
      scope = "user";
      attr = "neovim";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [];
      notes = "Adds to your userPackages.";
    }
    {
      id = "git";
      title = "Git";
      aliases = [ "git" ];
      description = "Git version control";
      category = "dev";
      kind = "attr";
      scope = "user";
      attr = "git";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [];
      notes = "Often already on the system; safe to add for your user.";
    }
    {
      id = "nodejs";
      title = "Node.js";
      aliases = [ "nodejs" "node" "npm" ];
      description = "Node.js runtime";
      category = "dev";
      kind = "attr";
      scope = "user";
      attr = "nodejs";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "python" ];
      notes = "For a fuller toolchain, use user preset user-web-tools under Recipes & sets.";
    }
    {
      id = "python";
      title = "Python";
      aliases = [ "python" "python3" ];
      description = "Python 3 interpreter";
      category = "dev";
      kind = "attr";
      scope = "user";
      attr = "python3";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "nodejs" ];
      notes = "For a fuller toolchain, use user preset user-python-tools under Recipes & sets.";
    }

    # ── Games ─────────────────────────────────────────────────────────────
    {
      id = "steam";
      title = "Steam";
      aliases = [ "steam" "valve" "steam deck" ];
      description = "Steam client package";
      category = "games";
      kind = "attr";
      scope = "user";
      attr = "steam";
      module = null;
      partOfSet = "gaming";
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = true;
      related = [ "lutris" "heroic" "mangohud" ];
      notes = "Adds pkgs.steam to your userPackages. For programs.steam + Lutris/Heroic/Vesktop, enable the gaming set under Recipes & sets.";
    }
    {
      id = "lutris";
      title = "Lutris";
      aliases = [ "lutris" ];
      description = "Lutris game launcher (Wine, Battle.net, …)";
      category = "games";
      kind = "attr";
      scope = "user";
      attr = "lutris";
      module = null;
      partOfSet = "gaming";
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "steam" "wow" ];
      notes = "Also part of the gaming set. For WoW / Battle.net, Lutris is typical.";
    }
    {
      id = "heroic";
      title = "Heroic Games Launcher";
      aliases = [ "heroic" "epic" "epic games" "gog" ];
      description = "Epic Games & GOG launcher";
      category = "games";
      kind = "attr";
      scope = "user";
      attr = "heroic";
      module = null;
      partOfSet = "gaming";
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "steam" "lutris" ];
      notes = "Also included in the gaming set.";
    }
    {
      id = "mangohud";
      title = "MangoHud";
      aliases = [ "mangohud" "mango hud" ];
      description = "Vulkan/OpenGL performance overlay";
      category = "games";
      kind = "attr";
      scope = "user";
      attr = "mangohud";
      module = null;
      partOfSet = "gaming";
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "steam" ];
      notes = "Also included in the gaming set.";
    }
    {
      id = "wow";
      title = "World of Warcraft";
      aliases = [ "wow" "world of warcraft" "warcraft" "battle.net" "battlenet" "battle net" ];
      description = "Game — not a nixpkgs package; install via Lutris / Steam";
      category = "games";
      kind = "guided";
      scope = "user";
      attr = null;
      module = null;
      partOfSet = "gaming";
      tryable = false;
      requiresAdmin = false;
      requiresUnfree = true;
      related = [ "lutris" "steam" ];
      notes = "NCC cannot install the game binary. Add Lutris (or the gaming set under Recipes & sets), then install WoW via Battle.net / Lutris.";
    }

    # ── Creative ──────────────────────────────────────────────────────────
    {
      id = "gimp";
      title = "GIMP";
      aliases = [ "gimp" ];
      description = "GNU Image Manipulation Program";
      category = "creative";
      kind = "attr";
      scope = "user";
      attr = "gimp";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "krita" ];
      notes = "Adds to your userPackages. Bundle: user-creative under Recipes & sets.";
    }
    {
      id = "krita";
      title = "Krita";
      aliases = [ "krita" ];
      description = "Digital painting studio";
      category = "creative";
      kind = "attr";
      scope = "user";
      attr = "krita";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "gimp" ];
      notes = "Adds to your userPackages.";
    }
    {
      id = "blender";
      title = "Blender";
      aliases = [ "blender" ];
      description = "3D creation suite";
      category = "creative";
      kind = "attr";
      scope = "user";
      attr = "blender";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "gimp" ];
      notes = "Adds to your userPackages. Bundle: user-creative under Recipes & sets.";
    }
    {
      id = "inkscape";
      title = "Inkscape";
      aliases = [ "inkscape" ];
      description = "Vector graphics editor";
      category = "creative";
      kind = "attr";
      scope = "user";
      attr = "inkscape";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "gimp" ];
      notes = "Adds to your userPackages.";
    }

    # ── Office ────────────────────────────────────────────────────────────
    {
      id = "libreoffice";
      title = "LibreOffice";
      aliases = [ "libreoffice" "office" "writer" "calc" ];
      description = "LibreOffice suite";
      category = "office";
      kind = "attr";
      scope = "user";
      attr = "libreoffice";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [];
      notes = "May already be on desktop profile machines.";
    }
    {
      id = "obsidian";
      title = "Obsidian";
      aliases = [ "obsidian" ];
      description = "Markdown knowledge base";
      category = "office";
      kind = "attr";
      scope = "user";
      attr = "obsidian";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = true;
      related = [];
      notes = "Unfree; ensure allowUnfree is enabled.";
    }

    # ── Media ─────────────────────────────────────────────────────────────
    {
      id = "vlc";
      title = "VLC";
      aliases = [ "vlc" ];
      description = "VLC media player";
      category = "media";
      kind = "attr";
      scope = "user";
      attr = "vlc";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "mpv" ];
      notes = "Adds to your userPackages.";
    }
    {
      id = "mpv";
      title = "mpv";
      aliases = [ "mpv" ];
      description = "mpv media player";
      category = "media";
      kind = "attr";
      scope = "user";
      attr = "mpv";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "vlc" ];
      notes = "Adds to your userPackages.";
    }
    {
      id = "obs";
      title = "OBS Studio";
      aliases = [ "obs" "obs studio" "obs-studio" ];
      description = "Open Broadcaster Software";
      category = "media";
      kind = "attr";
      scope = "user";
      attr = "obs-studio";
      module = null;
      partOfSet = "streaming";
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "vlc" "mpv" ];
      notes = "Adds obs-studio to your userPackages. For OBS + wlrobs + streamlink, enable the streaming set under Recipes & sets.";
    }
    {
      id = "spotify";
      title = "Spotify";
      aliases = [ "spotify" ];
      description = "Spotify client";
      category = "media";
      kind = "attr";
      scope = "user";
      attr = "spotify";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = true;
      related = [];
      notes = "Unfree; ensure allowUnfree is enabled.";
    }

    # ── System tools ──────────────────────────────────────────────────────
    {
      id = "htop";
      title = "htop";
      aliases = [ "htop" ];
      description = "Interactive process viewer";
      category = "system";
      kind = "attr";
      scope = "user";
      attr = "htop";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "btop" ];
      notes = "Adds to your userPackages.";
    }
    {
      id = "btop";
      title = "btop";
      aliases = [ "btop" ];
      description = "Resource monitor";
      category = "system";
      kind = "attr";
      scope = "user";
      attr = "btop";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [ "htop" ];
      notes = "Adds to your userPackages.";
    }
    {
      id = "ripgrep";
      title = "ripgrep";
      aliases = [ "ripgrep" "rg" ];
      description = "Fast recursive search (rg)";
      category = "system";
      kind = "attr";
      scope = "user";
      attr = "ripgrep";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [];
      notes = "Binary name is rg; package attr is ripgrep.";
    }
    {
      id = "jq";
      title = "jq";
      aliases = [ "jq" ];
      description = "JSON command-line processor";
      category = "system";
      kind = "attr";
      scope = "user";
      attr = "jq";
      module = null;
      partOfSet = null;
      tryable = true;
      requiresAdmin = false;
      requiresUnfree = false;
      related = [];
      notes = "Adds to your userPackages.";
    }
  ];
}
