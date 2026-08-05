{
  desktop_mapping = {
    linux = {
      GNOME = {
        alternatives = [ ];
        preferred_de = "gnome";
      };
      KDE = {
        alternatives = [ ];
        preferred_de = "plasma";
      };
      XFCE = {
        alternatives = [ ];
        preferred_de = "xfce";
      };
      default = {
        alternatives = [
          "gnome"
          "xfce"
        ];
        preferred_de = "plasma";
      };
      gnome = {
        alternatives = [ ];
        preferred_de = "gnome";
      };
      kde = {
        alternatives = [ ];
        preferred_de = "plasma";
      };
      xfce = {
        alternatives = [ ];
        preferred_de = "xfce";
      };
    };
    macos = {
      alternatives = [
        "plasma"
        "pantheon"
      ];
      preferred_de = "gnome";
    };
    windows = {
      alternatives = [
        "gnome"
        "xfce"
      ];
      preferred_de = "plasma";
    };
  };
  package_manager_mapping = {
    apt = { };
    chocolatey = { };
    dnf = { };
    homebrew = { };
    pacman = { };
    zypper = { };
  };
  programs = {
    "7-Zip" = {
      aliases = [
        "7zip"
        "7-Zip"
        "p7zip"
      ];
      alternatives = [
        {
          name = "p7zip";
          package = "p7zip";
          reason_key = "mappings.programs.7zip.alternatives.p7zip.reason";
        }
        {
          name = "unzip";
          package = "unzip";
          reason_key = "mappings.programs.7zip.alternatives.unzip.reason";
        }
        {
          name = "zip";
          package = "zip";
          reason_key = "mappings.programs.7zip.alternatives.zip.reason";
        }
      ];
      category = "utilities";
      module = null;
      nixos_package = "p7zip";
      priority = "normal";
    };
    "Adobe Acrobat Reader" = {
      aliases = [
        "acrobat"
        "Adobe Reader"
        "okular"
      ];
      alternatives = [
        {
          name = "Okular";
          package = "okular";
          reason_key = "mappings.programs.adobe_acrobat_reader.alternatives.okular.reason";
        }
        {
          name = "Evince";
          package = "evince";
          reason_key = "mappings.programs.adobe_acrobat_reader.alternatives.evince.reason";
        }
        {
          name = "Zathura";
          package = "zathura";
          reason_key = "mappings.programs.adobe_acrobat_reader.alternatives.zathura.reason";
        }
      ];
      category = "utilities";
      module = null;
      nixos_package = "okular";
      note_key = "mappings.programs.adobe_acrobat_reader.note";
      priority = "high";
      wine = true;
    };
    "Adobe Illustrator" = {
      aliases = [
        "illustrator"
        "Adobe Illustrator"
        "AI"
      ];
      alternatives = [
        {
          name = "Inkscape";
          package = "inkscape";
          reason_key = "mappings.programs.adobe_illustrator.alternatives.inkscape.reason";
        }
        {
          name = "Krita";
          package = "krita";
          reason_key = "mappings.programs.adobe_illustrator.alternatives.krita.reason";
        }
      ];
      category = "multimedia";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.adobe_illustrator.note";
      priority = "high";
      wine = true;
    };
    "Adobe Photoshop" = {
      aliases = [
        "photoshop"
        "Adobe Photoshop"
        "PS"
      ];
      alternatives = [
        {
          name = "GIMP";
          package = "gimp";
          reason_key = "mappings.programs.adobe_photoshop.alternatives.gimp.reason";
        }
        {
          name = "Krita";
          package = "krita";
          reason_key = "mappings.programs.adobe_photoshop.alternatives.krita.reason";
        }
        {
          name = "Darktable";
          package = "darktable";
          reason_key = "mappings.programs.adobe_photoshop.alternatives.darktable.reason";
        }
      ];
      category = "multimedia";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.adobe_photoshop.note";
      priority = "top";
      short_description_key = "mappings.programs.adobe_photoshop.short_description";
      wine = true;
    };
    Audacity = {
      aliases = [
        "audacity"
        "Audacity"
      ];
      alternatives = [
        {
          name = "Ardour";
          package = "ardour";
          reason_key = "mappings.programs.audacity.alternatives.ardour.reason";
        }
        {
          name = "Reaper";
          package = null;
          reason_key = "mappings.programs.audacity.alternatives.reaper.reason";
        }
      ];
      category = "audio";
      module = null;
      nixos_package = "audacity";
      priority = "normal";
    };
    Bitwarden = {
      aliases = [
        "bitwarden"
        "Bitwarden"
      ];
      alternatives = [
        {
          name = "KeePassXC";
          package = "keepassxc";
          reason_key = "mappings.programs.bitwarden.alternatives.keepassxc.reason";
        }
        {
          name = "pass";
          package = "pass";
          reason_key = "mappings.programs.bitwarden.alternatives.pass.reason";
        }
      ];
      category = "security";
      module = null;
      nixos_package = "bitwarden";
      priority = "high";
    };
    Blender = {
      aliases = [
        "blender"
        "Blender"
      ];
      category = "graphics";
      module = null;
      nixos_package = "blender";
      priority = "normal";
    };
    Brave = {
      aliases = [
        "brave"
        "Brave"
        "Brave Browser"
      ];
      alternatives = [
        {
          name = "Firefox";
          package = "firefox";
          reason_key = "mappings.programs.brave.alternatives.firefox.reason";
        }
        {
          name = "LibreWolf";
          package = "librewolf";
          reason_key = "mappings.programs.brave.alternatives.librewolf.reason";
        }
      ];
      category = "browser";
      module = null;
      nixos_package = "brave";
      priority = "high";
    };
    CCleaner = {
      aliases = [
        "ccleaner"
        "CCleaner"
      ];
      alternatives = [
        {
          name = "nix-collect-garbage";
          package = null;
          reason_key = "mappings.programs.ccleaner.alternatives.nix_collect_garbage.reason";
        }
        {
          name = "ncdu";
          package = "ncdu";
          reason_key = "mappings.programs.ccleaner.alternatives.ncdu.reason";
        }
        {
          name = "baobab";
          package = "baobab";
          reason_key = "mappings.programs.ccleaner.alternatives.baobab.reason";
        }
      ];
      category = "utilities";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.ccleaner.note";
      priority = "normal";
    };
    Chromium = {
      aliases = [
        "chromium"
      ];
      category = "browser";
      module = null;
      nixos_package = "chromium";
      priority = "normal";
    };
    ClamWin = {
      aliases = [
        "clamwin"
        "ClamWin"
      ];
      alternatives = [
        {
          name = "ClamAV";
          package = "clamav";
          reason_key = "mappings.programs.clamwin.alternatives.clamav.reason";
        }
      ];
      category = "security";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.clamwin.note";
      priority = "normal";
    };
    "Code::Blocks" = {
      aliases = [
        "codeblocks"
        "Code::Blocks"
      ];
      alternatives = [
        {
          name = "Visual Studio Code";
          package = "vscode";
          reason_key = "mappings.programs.codeblocks.alternatives.vscode.reason";
        }
      ];
      category = "development";
      module = null;
      nixos_package = "codeblocks";
      priority = "normal";
    };
    Discord = {
      aliases = [
        "discord"
      ];
      alternatives = [
        {
          name = "Vesktop";
          package = "vesktop";
          reason_key = "mappings.programs.discord.alternatives.vesktop.reason";
        }
      ];
      category = "communication";
      module = null;
      nixos_package = "discord";
      priority = "high";
    };
    "Docker Desktop" = {
      aliases = [
        "docker"
        "Docker"
        "Docker Desktop"
      ];
      category = "infrastructure";
      module = "modules.infrastructure.homelab-manager";
      nixos_package = "docker";
      priority = "high";
    };
    Doublecmd = {
      aliases = [
        "doublecmd"
        "Doublecmd"
      ];
      category = "utilities";
      module = null;
      nixos_package = "doublecmd";
      priority = "normal";
    };
    Dropbox = {
      aliases = [
        "dropbox"
        "Dropbox"
      ];
      alternatives = [
        {
          name = "Nextcloud";
          package = "nextcloud-client";
          reason_key = "mappings.programs.dropbox.alternatives.nextcloud.reason";
        }
        {
          name = "Syncthing";
          package = "syncthing";
          reason_key = "mappings.programs.dropbox.alternatives.syncthing.reason";
        }
        {
          name = "rclone";
          package = "rclone";
          reason_key = "mappings.programs.dropbox.alternatives.rclone.reason";
        }
      ];
      category = "utilities";
      module = null;
      nixos_package = "dropbox";
      priority = "high";
    };
    Evernote = {
      aliases = [
        "evernote"
        "Evernote"
      ];
      alternatives = [
        {
          name = "Joplin";
          package = "joplin-desktop";
          reason_key = "mappings.programs.evernote.alternatives.joplin.reason";
        }
        {
          name = "Obsidian";
          package = "obsidian";
          reason_key = "mappings.programs.evernote.alternatives.obsidian.reason";
        }
        {
          name = "Standard Notes";
          package = "standardnotes";
          reason_key = "mappings.programs.evernote.alternatives.standard_notes.reason";
        }
      ];
      category = "productivity";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.evernote.note";
      priority = "normal";
    };
    Firefox = {
      aliases = [
        "firefox"
        "Mozilla Firefox"
      ];
      alternatives = [
        {
          name = "LibreWolf";
          package = "librewolf";
          reason_key = "mappings.programs.firefox.alternatives.librewolf.reason";
        }
        {
          name = "Tor Browser";
          package = "tor-browser-bundle-bin";
          reason_key = "mappings.programs.firefox.alternatives.tor_browser.reason";
        }
      ];
      category = "browser";
      module = null;
      nixos_package = "firefox";
      priority = "high";
    };
    Freeplane = {
      aliases = [
        "freeplane"
        "Freeplane"
      ];
      category = "productivity";
      module = null;
      nixos_package = "freeplane";
      priority = "normal";
    };
    GIMP = {
      aliases = [
        "gimp"
        "GIMP"
        "GNU Image Manipulation Program"
      ];
      alternatives = [
        {
          name = "Krita";
          package = "krita";
          reason_key = "mappings.programs.gimp.alternatives.krita.reason";
        }
        {
          name = "Darktable";
          package = "darktable";
          reason_key = "mappings.programs.gimp.alternatives.darktable.reason";
        }
      ];
      category = "graphics";
      module = null;
      nixos_package = "gimp";
      priority = "normal";
    };
    Git = {
      aliases = [
        "git"
        "Git"
      ];
      category = "development";
      module = null;
      nixos_package = "git";
      priority = "normal";
    };
    "GitHub Desktop" = {
      aliases = [
        "github-desktop"
        "GitHub Desktop"
      ];
      alternatives = [
        {
          name = "Lazygit";
          package = "lazygit";
          reason_key = "mappings.programs.github_desktop.alternatives.lazygit.reason";
        }
        {
          name = "GitKraken";
          package = "gitkraken";
          reason_key = "mappings.programs.github_desktop.alternatives.gitkraken.reason";
        }
        {
          name = "Git CLI";
          package = "git";
          reason_key = "mappings.programs.github_desktop.alternatives.git_cli.reason";
        }
      ];
      category = "development";
      module = null;
      nixos_package = "github-desktop";
      priority = "high";
    };
    "Google Chrome" = {
      aliases = [
        "chrome"
        "Google Chrome"
        "Chrome"
      ];
      alternatives = [
        {
          name = "Chromium";
          package = "chromium";
          reason_key = "mappings.programs.google_chrome.alternatives.chromium.reason";
        }
        {
          name = "Firefox";
          package = "firefox";
          reason_key = "mappings.programs.google_chrome.alternatives.firefox.reason";
        }
      ];
      category = "browser";
      module = null;
      nixos_package = "google-chrome";
      priority = "top";
      short_description_key = "mappings.programs.google_chrome.short_description";
    };
    "Google Drive" = {
      aliases = [
        "googledrive"
        "Google Drive"
        "gdrive"
      ];
      alternatives = [
        {
          name = "rclone";
          package = "rclone";
          reason_key = "mappings.programs.google_drive.alternatives.rclone.reason";
        }
        {
          name = "Nextcloud";
          package = "nextcloud-client";
          reason_key = "mappings.programs.google_drive.alternatives.nextcloud.reason";
        }
        {
          name = "Syncthing";
          package = "syncthing";
          reason_key = "mappings.programs.google_drive.alternatives.syncthing.reason";
        }
      ];
      category = "utilities";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.google_drive.note";
      priority = "normal";
    };
    Handbrake = {
      aliases = [
        "handbrake"
        "Handbrake"
      ];
      category = "multimedia";
      module = null;
      nixos_package = "handbrake";
      priority = "normal";
    };
    Inkscape = {
      aliases = [
        "inkscape"
        "Inkscape"
      ];
      alternatives = [
        {
          name = "Krita";
          package = "krita";
          reason_key = "mappings.programs.inkscape.alternatives.krita.reason";
        }
        {
          name = "Scribus";
          package = "scribus";
          reason_key = "mappings.programs.inkscape.alternatives.scribus.reason";
        }
      ];
      category = "graphics";
      module = null;
      nixos_package = "inkscape";
      priority = "normal";
    };
    Krita = {
      aliases = [
        "krita"
        "Krita"
      ];
      alternatives = [
        {
          name = "GIMP";
          package = "gimp";
          reason_key = "mappings.programs.krita.alternatives.gimp.reason";
        }
        {
          name = "Inkscape";
          package = "inkscape";
          reason_key = "mappings.programs.krita.alternatives.inkscape.reason";
        }
      ];
      category = "graphics";
      module = null;
      nixos_package = "krita";
      priority = "normal";
    };
    Lazarus = {
      aliases = [
        "lazarus"
        "Lazarus"
      ];
      category = "development";
      module = null;
      nixos_package = "lazarus";
      priority = "normal";
    };
    LibreOffice = {
      aliases = [
        "libreoffice"
        "LibreOffice"
        "LO"
      ];
      alternatives = [
        {
          name = "OnlyOffice";
          package = "onlyoffice-bin";
          reason_key = "mappings.programs.libreoffice.alternatives.onlyoffice.reason";
        }
        {
          name = "OpenOffice";
          package = "apache-openoffice";
          reason_key = "mappings.programs.libreoffice.alternatives.openoffice.reason";
        }
      ];
      category = "productivity";
      module = null;
      nixos_package = "libreoffice";
      priority = "high";
    };
    LocalSend = {
      aliases = [
        "localsend"
        "LocalSend"
      ];
      category = "utilities";
      module = null;
      nixos_package = "localsend";
      priority = "normal";
    };
    "Microsoft Office" = {
      aliases = [
        "office"
        "Microsoft Office"
        "libreoffice"
        "LibreOffice"
      ];
      alternatives = [
        {
          name = "OnlyOffice";
          package = "onlyoffice-bin";
          reason_key = "mappings.programs.microsoft_office.alternatives.onlyoffice.reason";
        }
        {
          name = "LibreOffice";
          package = "libreoffice";
          reason_key = "mappings.programs.microsoft_office.alternatives.libreoffice.reason";
        }
      ];
      category = "productivity";
      module = null;
      nixos_package = "libreoffice";
      note_key = "mappings.programs.microsoft_office.note";
      priority = "top";
      short_description_key = "mappings.programs.microsoft_office.short_description";
      wine = true;
    };
    Mumble = {
      aliases = [
        "mumble"
        "Mumble"
      ];
      alternatives = [
        {
          name = "Discord";
          package = "discord";
          reason_key = "mappings.programs.mumble.alternatives.discord.reason";
        }
        {
          name = "TeamSpeak";
          package = null;
          reason_key = "mappings.programs.mumble.alternatives.teamspeak.reason";
        }
      ];
      category = "communication";
      module = null;
      nixos_package = "mumble";
      priority = "normal";
    };
    "Node.js" = {
      aliases = [
        "node"
        "nodejs"
        "Node.js"
      ];
      category = "development";
      module = null;
      nixos_package = "nodejs";
      priority = "normal";
    };
    "Notepad++" = {
      aliases = [
        "notepad++"
        "Notepad++"
        "notepadqq"
      ];
      alternatives = [
        {
          name = "Notepadqq";
          package = "notepadqq";
          reason_key = "mappings.programs.notepad_plus_plus.alternatives.notepadqq.reason";
        }
        {
          name = "Kate";
          package = "kate";
          reason_key = "mappings.programs.notepad_plus_plus.alternatives.kate.reason";
        }
        {
          name = "Gedit";
          package = "gedit";
          reason_key = "mappings.programs.notepad_plus_plus.alternatives.gedit.reason";
        }
      ];
      category = "development";
      module = null;
      nixos_package = "notepadqq";
      priority = "high";
    };
    "Obs Studio" = {
      aliases = [
        "obs"
        "OBS Studio"
        "obs-studio"
      ];
      category = "multimedia";
      module = null;
      nixos_package = "obs-studio";
      priority = "normal";
    };
    Obsidian = {
      aliases = [
        "obsidian"
        "Obsidian"
      ];
      alternatives = [
        {
          name = "Joplin";
          package = "joplin-desktop";
          reason_key = "mappings.programs.obsidian.alternatives.joplin.reason";
        }
        {
          name = "Logseq";
          package = "logseq";
          reason_key = "mappings.programs.obsidian.alternatives.logseq.reason";
        }
      ];
      category = "productivity";
      module = null;
      nixos_package = "obsidian";
      priority = "normal";
    };
    Python = {
      aliases = [
        "python"
        "python3"
        "Python"
      ];
      category = "development";
      module = null;
      nixos_package = "python3";
      priority = "normal";
    };
    Rufus = {
      aliases = [
        "rufus"
        "Rufus"
      ];
      alternatives = [
        {
          name = "Ventoy";
          package = "ventoy";
          reason_key = "mappings.programs.rufus.alternatives.ventoy.reason";
        }
        {
          name = "dd";
          package = null;
          reason_key = "mappings.programs.rufus.alternatives.dd.reason";
        }
      ];
      category = "utilities";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.rufus.note";
      priority = "normal";
    };
    Scribus = {
      aliases = [
        "scribus"
        "Scribus"
      ];
      category = "graphics";
      module = null;
      nixos_package = "scribus";
      priority = "normal";
    };
    Signal = {
      aliases = [
        "signal"
        "Signal"
        "Signal Desktop"
      ];
      alternatives = [
        {
          name = "Element";
          package = "element-desktop";
          reason_key = "mappings.programs.signal.alternatives.element.reason";
        }
        {
          name = "Threema";
          package = null;
          reason_key = "mappings.programs.signal.alternatives.threema.reason";
        }
      ];
      category = "communication";
      module = null;
      nixos_package = "signal-desktop";
      priority = "high";
    };
    Slack = {
      aliases = [
        "slack"
      ];
      alternatives = [
        {
          name = "Element";
          package = "element-desktop";
          reason_key = "mappings.programs.slack.alternatives.element.reason";
        }
        {
          name = "Rocket.Chat";
          package = "rocketchat-desktop";
          reason_key = "mappings.programs.slack.alternatives.rocketchat.reason";
        }
      ];
      category = "communication";
      module = null;
      nixos_package = "slack";
      priority = "normal";
    };
    Spotify = {
      aliases = [
        "spotify"
      ];
      alternatives = [
        {
          name = "ncspot";
          package = "ncspot";
          reason_key = "mappings.programs.spotify.alternatives.ncspot.reason";
        }
        {
          name = "Spotify-tui";
          package = "spotify-tui";
          reason_key = "mappings.programs.spotify.alternatives.spotify_tui.reason";
        }
      ];
      category = "multimedia";
      module = null;
      nixos_package = "spotify";
      priority = "high";
    };
    Steam = {
      aliases = [
        "steam"
      ];
      category = "gaming";
      module = null;
      nixos_package = "steam";
      note_key = "mappings.programs.steam.note";
      priority = "top";
      proton = true;
      short_description_key = "mappings.programs.steam.short_description";
    };
    Stellarium = {
      aliases = [
        "stellarium"
        "Stellarium"
      ];
      category = "education";
      module = null;
      nixos_package = "stellarium";
      priority = "normal";
    };
    "Sweet Home 3D" = {
      aliases = [
        "sweethome3d"
        "Sweet Home 3D"
      ];
      category = "graphics";
      module = null;
      nixos_package = "sweethome3d";
      priority = "normal";
    };
    TeamViewer = {
      aliases = [
        "teamviewer"
        "TeamViewer"
      ];
      alternatives = [
        {
          name = "AnyDesk";
          package = "anydesk";
          reason_key = "mappings.programs.teamviewer.alternatives.anydesk.reason";
        }
        {
          name = "RustDesk";
          package = "rustdesk";
          reason_key = "mappings.programs.teamviewer.alternatives.rustdesk.reason";
        }
        {
          name = "Remmina";
          package = "remmina";
          reason_key = "mappings.programs.teamviewer.alternatives.remmina.reason";
        }
      ];
      category = "communication";
      module = null;
      nixos_package = "teamviewer";
      priority = "high";
    };
    Thunderbird = {
      aliases = [
        "thunderbird"
        "Thunderbird"
      ];
      alternatives = [
        {
          name = "Evolution";
          package = "evolution";
          reason_key = "mappings.programs.thunderbird.alternatives.evolution.reason";
        }
        {
          name = "Geary";
          package = "geary";
          reason_key = "mappings.programs.thunderbird.alternatives.geary.reason";
        }
        {
          name = "KMail";
          package = "kdePackages.kmail";
          reason_key = "mappings.programs.thunderbird.alternatives.kmail.reason";
        }
      ];
      category = "communication";
      module = null;
      nixos_package = "thunderbird";
      priority = "normal";
    };
    TortoiseSVN = {
      aliases = [
        "tortoisesvn"
        "TortoiseSVN"
      ];
      alternatives = [
        {
          name = "Git";
          package = "git";
          reason_key = "mappings.programs.tortoisesvn.alternatives.git.reason";
        }
      ];
      category = "development";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.tortoisesvn.note";
      priority = "normal";
    };
    VLC = {
      aliases = [
        "vlc"
        "VLC media player"
      ];
      alternatives = [
        {
          name = "MPV";
          package = "mpv";
          reason_key = "mappings.programs.vlc.alternatives.mpv.reason";
        }
        {
          name = "SMPlayer";
          package = "smplayer";
          reason_key = "mappings.programs.vlc.alternatives.smplayer.reason";
        }
      ];
      category = "multimedia";
      module = null;
      nixos_package = "vlc";
      priority = "high";
    };
    VMware = {
      aliases = [
        "vmware"
        "VMware"
      ];
      category = "virtualization";
      module = "modules.infrastructure.vm-manager";
      nixos_package = null;
      priority = "high";
    };
    VirtualBox = {
      aliases = [
        "virtualbox"
        "VirtualBox"
      ];
      alternatives = [
        {
          name = "QEMU/KVM";
          package = "qemu";
          reason_key = "mappings.programs.virtualbox.alternatives.qemu_kvm.reason";
        }
      ];
      category = "virtualization";
      module = null;
      nixos_package = "virtualbox";
      priority = "high";
    };
    "Visual Studio Code" = {
      aliases = [
        "vscode"
        "code"
        "Visual Studio Code"
        "VS Code"
      ];
      alternatives = [
        {
          name = "VSCodium";
          package = "vscodium";
          reason_key = "mappings.programs.visual_studio_code.alternatives.vscodium.reason";
        }
        {
          name = "Neovim";
          package = "neovim";
          reason_key = "mappings.programs.visual_studio_code.alternatives.neovim.reason";
        }
        {
          name = "Helix";
          package = "helix";
          reason_key = "mappings.programs.visual_studio_code.alternatives.helix.reason";
        }
      ];
      category = "development";
      module = null;
      nixos_package = "vscode";
      priority = "top";
      short_description_key = "mappings.programs.visual_studio_code.short_description";
    };
    WinMerge = {
      aliases = [
        "winmerge"
        "WinMerge"
      ];
      alternatives = [
        {
          name = "Meld";
          package = "meld";
          reason_key = "mappings.programs.winmerge.alternatives.meld.reason";
        }
        {
          name = "Kompare";
          package = "kompare";
          reason_key = "mappings.programs.winmerge.alternatives.kompare.reason";
        }
      ];
      category = "development";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.winmerge.note";
      priority = "normal";
    };
    WinRAR = {
      aliases = [
        "winrar"
        "WinRAR"
        "unrar"
      ];
      alternatives = [
        {
          name = "unrar";
          package = "unrar";
          reason_key = "mappings.programs.winrar.alternatives.unrar.reason";
        }
        {
          name = "p7zip";
          package = "p7zip";
          reason_key = "mappings.programs.winrar.alternatives.p7zip.reason";
        }
      ];
      category = "utilities";
      module = null;
      nixos_package = "unrar";
      priority = "normal";
    };
    WinSCP = {
      aliases = [
        "winscp"
        "WinSCP"
      ];
      alternatives = [
        {
          name = "FileZilla";
          package = "filezilla";
          reason_key = "mappings.programs.winscp.alternatives.filezilla.reason";
        }
        {
          name = "rsync";
          package = "rsync";
          reason_key = "mappings.programs.winscp.alternatives.rsync.reason";
        }
      ];
      category = "utilities";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.winscp.note";
      priority = "normal";
    };
    iTerm2 = {
      aliases = [
        "iterm"
        "iTerm2"
        "alacritty"
      ];
      alternatives = [
        {
          name = "Alacritty";
          package = "alacritty";
          reason_key = "mappings.programs.iterm2.alternatives.alacritty.reason";
        }
        {
          name = "Kitty";
          package = "kitty";
          reason_key = "mappings.programs.iterm2.alternatives.kitty.reason";
        }
        {
          name = "WezTerm";
          package = "wezterm";
          reason_key = "mappings.programs.iterm2.alternatives.wezterm.reason";
        }
      ];
      category = "utilities";
      module = null;
      nixos_package = "alacritty";
      priority = "normal";
    };
    qBittorrent = {
      aliases = [
        "qbittorrent"
        "qBittorrent"
        "qb"
      ];
      category = "utilities";
      module = null;
      nixos_package = "qbittorrent";
      priority = "normal";
    };
    "uBlock Origin" = {
      aliases = [
        "ublock"
        "uBlock Origin"
        "ublock-origin"
      ];
      alternatives = [
        {
          name = "uBlock Origin (Browser Extension)";
          package = null;
          reason_key = "mappings.programs.ublock_origin.alternatives.extension.reason";
        }
        {
          name = "AdBlock Plus";
          package = null;
          reason_key = "mappings.programs.ublock_origin.alternatives.adblock.reason";
        }
      ];
      category = "browser";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.ublock_origin.note";
      priority = "normal";
    };
    "µTorrent" = {
      aliases = [
        "utorrent"
        "µTorrent"
        "uTorrent"
      ];
      alternatives = [
        {
          name = "qBittorrent";
          package = "qbittorrent";
          reason_key = "mappings.programs.utorrent.alternatives.qbittorrent.reason";
        }
        {
          name = "Transmission";
          package = "transmission";
          reason_key = "mappings.programs.utorrent.alternatives.transmission.reason";
        }
        {
          name = "Deluge";
          package = "deluge";
          reason_key = "mappings.programs.utorrent.alternatives.deluge.reason";
        }
      ];
      category = "utilities";
      module = null;
      nixos_package = null;
      note_key = "mappings.programs.utorrent.note";
      priority = "normal";
    };
  };
  version = "0.1.0";
}
