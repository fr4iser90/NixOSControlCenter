# Curated Hall of Fame rices — SSOT for ncc hyprland rice/wallpaper catalog.
# Source: https://hypr.land/hall_of_fame/
#
# applyMethod:
#   dotfiles  — clone upstream repo to /var/lib/ncc/hyprland/collections/<id>/ on install
#   flake     — dotfiles fetch + flake input/module patch in host flake.nix
#   wallpaper — wallpaper only (no upstream repo)
#   reference — catalog metadata only (not in store)
let
  parse = import ./parse-dotfiles-url.nix;
  paths = import ./paths.nix;

  withDotfiles = attrs:
    let git = parse (attrs.dotfilesUrl or "");
    in {
      dotfiles = git // { hyprCandidates = paths.hyprConfigCandidates; };
    };

  df = attrs:
    withDotfiles attrs
    // attrs
    // { applyMethod = "dotfiles"; };

  fk = attrs: flake:
    let
      inputName = flake.inputName or "hyprland-${attrs.id}";
    in
      withDotfiles attrs
      // attrs
      // {
        applyMethod = "flake";
        flake = flake // { inherit inputName; };
      };

  wp = attrs: attrs // { applyMethod = "wallpaper"; };
in {
  astroland = df {
    id = "astroland";
    name = "Astroland";
    creator = "zacoons";
    contest = 5;
    theme = "Moon";
    rank = 1;
    dotfilesUrl = "https://codeberg.org/zacoons/astroland_dots";
    thumbnailUrl = "https://hypr.land/ricing_competitions/5/zacoons.png";
    thumbnailHash = "sha256-u47+/9JWXfnZHClPOd2ZG46h7iT+zebrXK9AJMwKoRM=";
    nixosNative = false;
    description = "Contest #5 winner — moon-themed astroland rice.";
  };

  moon-rice = df {
    id = "moon-rice";
    name = "Moon Rice";
    creator = "Flafy";
    contest = 5;
    theme = "Moon";
    rank = 2;
    dotfilesUrl = "https://github.com/FlafyDev/hyprland_moon_rice_public";
    thumbnailUrl = "https://hypr.land/ricing_competitions/5/flafy.png";
    thumbnailHash = "sha256-iHRgoIwUPvgk48Ek4ikjdpRWCBPBsQwXoJXgxzenyPs=";
    nixosNative = false;
    description = "Contest #5 runner-up — soft moon palette.";
  };

  space-rice = df {
    id = "space-rice";
    name = "SPACE";
    creator = "Ilyamiro";
    contest = 5;
    theme = "Moon";
    rank = 3;
    dotfilesUrl = "https://github.com/ilyamiro/hypr-comp";
    thumbnailUrl = "https://hypr.land/ricing_competitions/5/ilyamiro.png";
    thumbnailHash = "sha256-eymxFjf+KR2getXBo5PfbDLKwROiBNOM7GYtckZbQQ0=";
    nixosNative = false;
    description = "Contest #5 third place — deep space workflow.";
  };

  rivendell = df {
    id = "rivendell";
    name = "Rivendell";
    creator = "zacoons";
    contest = 4;
    theme = "Fantasy";
    rank = 1;
    dotfilesUrl = "https://codeberg.org/zacoons/rivendell-hyprdots";
    thumbnailUrl = "https://hypr.land/ricing_competitions/4/zacoons.webp";
    thumbnailHash = "sha256-OMtfv4cIYsr4EfxHLQLfTSn78F9OGmAsOuN8JNEVvPE=";
    nixosNative = false;
    description = "Contest #4 winner — fantasy elven aesthetic.";
  };

  disney-type-shi = df {
    id = "disney-type-shi";
    name = "Disney type shi";
    creator = "VDawg";
    contest = 4;
    theme = "Fantasy";
    rank = 2;
    dotfilesUrl = "https://github.com/vdawg-git/fantasy-rice";
    thumbnailUrl = "https://hypr.land/ricing_competitions/4/vdawg.webp";
    thumbnailHash = "sha256-+gdQYVIVaGGOpuemwgl5pHf0oxSP9AP45kaAWUxWhr4=";
    nixosNative = false;
    description = "Contest #4 runner-up — playful fantasy palette.";
  };

  duskhide = df {
    id = "duskhide";
    name = "Duskhide";
    creator = "Flafy";
    contest = 4;
    theme = "Fantasy";
    rank = 3;
    dotfilesUrl = "https://github.com/flafydev/fantasy_rice";
    thumbnailUrl = "https://hypr.land/ricing_competitions/4/flafy.webp";
    thumbnailHash = "sha256-tGYA4vf1RzMf9Hi46jTSeiUzToSnDbfz/KRF4D3Rf9o=";
    nixosNative = false;
    description = "Contest #4 third place — dusk fantasy tones.";
  };

  celestial = fk {
    id = "celestial";
    name = "Celestial";
    creator = "Flafy";
    contest = 3;
    theme = "Space";
    rank = 1;
    dotfilesUrl = "https://github.com/flafydev/nixos-config/";
    thumbnailUrl = "https://hypr.land/ricing_competitions/3/flafy.webp";
    thumbnailHash = "sha256-xHPyxHzIPt+tDaIzBSP/gIIzXOjCuZwWWXDS4AQycwg=";
    nixosNative = true;
    description = "Contest #3 winner — NixOS-native dotfiles.";
  } {
    url = "github:flafydev/nixos-config";
    ref = "master";
    inputName = "hyprland-celestial";
    nixosModule = "nixosModules.default";
  };

  globes = df {
    id = "globes";
    name = "Globes";
    creator = "Aylur";
    contest = 3;
    theme = "Space";
    rank = 2;
    dotfilesUrl = "https://github.com/Aylur/dotfiles/tree/ags-pre-ts";
    thumbnailUrl = "https://hypr.land/ricing_competitions/3/aylur.webp";
    thumbnailHash = "sha256-1/dBNWF0L+K1HDq9AJU9Xyxb2OTBZegG9OmAjy9Y+dc=";
    nixosNative = false;
    description = "Contest #3 runner-up — AGS globes layout.";
  };

  golden-era = df {
    id = "golden-era";
    name = "Golden Era";
    creator = "VDawg";
    contest = 3;
    theme = "Space";
    rank = 3;
    dotfilesUrl = "https://github.com/vdawg-git/space_dots";
    thumbnailUrl = "https://hypr.land/ricing_competitions/3/vdawg.webp";
    thumbnailHash = "sha256-NxeoawytKIomaLr0OcvDPnCOd1HYckzyJsJrzNhsHKw=";
    nixosNative = false;
    description = "Contest #3 third place — golden retro space.";
  };

  hybrid-summer = df {
    id = "hybrid-summer";
    name = "Hybrid Summer";
    creator = "end_4";
    contest = 2;
    theme = "Summer";
    rank = 1;
    dotfilesUrl = "https://github.com/end-4/dots-hyprland/tree/archive/hybrid-summer";
    thumbnailUrl = "https://hypr.land/ricing_competitions/2/end_4.webp";
    thumbnailHash = "sha256-w55IMNd5+F8Pl3WUsJhyaJi2TNRkw272UGJI0yAUKRg=";
    nixosNative = false;
    description = "Contest #2 winner — bright hybrid workflow.";
  };

  summer-unnamed = df {
    id = "summer-unnamed";
    name = "Summer (unnamed)";
    creator = "Flafy";
    contest = 2;
    theme = "Summer";
    rank = 2;
    dotfilesUrl = "https://github.com/FlafyDev/flutter_background_bar";
    thumbnailUrl = "https://hypr.land/ricing_competitions/2/flafy.webp";
    thumbnailHash = "sha256-FGJfNLEgtCTOevRniH3cbkbh1hzFQYMjimncxiUCc+s=";
    nixosNative = false;
    description = "Contest #2 runner-up — airy summer bar.";
  };

  day-and-night = df {
    id = "day-and-night";
    name = "Day and Night";
    creator = "Mathisbuilder";
    contest = 2;
    theme = "Summer";
    rank = 3;
    dotfilesUrl = "https://github.com/MathisP75/summer-day-and-night";
    thumbnailUrl = "https://hypr.land/ricing_competitions/2/day-night.webp";
    thumbnailHash = "sha256-oCzGvnDIHVIxrl2EaeVjmNZ/nTOEcOGiemGhJvY4dNQ=";
    nixosNative = false;
    description = "Contest #2 third place — dual summer theme.";
  };

  winter-flafy = df {
    id = "winter-flafy";
    name = "Winter (Flafy)";
    creator = "Flafy";
    contest = 1;
    theme = "Winter";
    rank = 1;
    dotfilesUrl = "https://github.com/FlafyDev/flutter_workspaces_2";
    thumbnailUrl = "https://hypr.land/ricing_competitions/1/flafy.webp";
    thumbnailHash = "sha256-tng7mjyZEeyPo2U7DjjwfOmHc6gzSOgKNQOs/071VXQ=";
    nixosNative = false;
    description = "Contest #1 winner — inaugural winter rice.";
  };

  aurora = df {
    id = "aurora";
    name = "Aurora";
    creator = "flick0";
    contest = 1;
    theme = "Winter";
    rank = 2;
    dotfilesUrl = "https://github.com/flick0/dotfiles/tree/aurora";
    thumbnailUrl = "https://hypr.land/ricing_competitions/1/flicko.webp";
    thumbnailHash = "sha256-GX/G0fYiLKsRMob0ov1DPiqXvKj1Vos2y/P0qzQjLVM=";
    nixosNative = false;
    description = "Contest #1 co-winner — northern lights palette.";
  };

  hyprland-winter = df {
    id = "hyprland-winter";
    name = "Hyprland Winter";
    creator = "amadeus";
    contest = 1;
    theme = "Winter";
    rank = 2;
    dotfilesUrl = "https://github.com/AmadeusWM/hyprland-winter";
    thumbnailUrl = "https://hypr.land/ricing_competitions/1/amadeus.webp";
    thumbnailHash = "sha256-KeC2YkC5P4Q9nnQMZ5K6+zEPXh1+YLJRnchMX8ewyBg=";
    nixosNative = false;
    description = "Contest #1 co-winner — classic Hyprland winter.";
  };

  lyasm-winter = {
    id = "lyasm-winter";
    name = "Winter (Lyasm)";
    creator = "Lyasm";
    contest = 1;
    theme = "Winter";
    rank = 3;
    dotfilesUrl = "";
    thumbnailUrl = "https://hypr.land/ricing_competitions/1/lyasm.webp";
    thumbnailHash = "sha256-kNwmAm3+18+eymnGltZq0XflLhktzJQiFBf68d/u3Mo=";
    applyMethod = "reference";
    nixosNative = false;
    description = "Contest #1 third place — preview only; no NCC apply preset yet.";
  };

  lauroro-winter = df {
    id = "lauroro-winter";
    name = "Winter (lauroro)";
    creator = "lauroro";
    contest = 1;
    theme = "Winter";
    rank = 3;
    dotfilesUrl = "https://github.com/lauroro/hyprland-dotfiles";
    thumbnailUrl = "https://hypr.land/ricing_competitions/1/lauroro.webp";
    thumbnailHash = "sha256-+5GPkME+GkBLA/wiVoNZI7ODIYIrw5YahM5gLeXsfl8=";
    nixosNative = false;
    description = "Contest #1 third place — cozy winter dots.";
  };
}
