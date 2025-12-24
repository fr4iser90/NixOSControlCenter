{ lib, colors }:

let
  self = {
    # Klassischer Spinner
    basic = phase: let
      frames = [ "|" "/" "-" "\\" ];
      index = lib.mod phase (builtins.length frames);
    in ''
      printf '\r%b' "${builtins.elemAt frames index} "
    '';

    # Dots Spinner
    dots = phase: let
      frames = [ "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" ];
      index = lib.mod phase (builtins.length frames);
    in ''
      printf '\r%b' "${builtins.elemAt frames index} "
    '';

    # Braille Spinner
    braille = phase: let
      frames = [ "⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷" ];
      index = lib.mod phase (builtins.length frames);
    in ''
      printf '\r%b' "${builtins.elemAt frames index} "
    '';

    # Line Spinner
    line = phase: let
      frames = [ "─" "\\" "|" "/" ];
      index = lib.mod phase (builtins.length frames);
    in ''
      printf '\r%b' "${builtins.elemAt frames index} "
    '';
  };
in
self // {
  # Mit Text
  withText = type: text: phase: let
    spinner = builtins.getAttr type self;
  in ''
    ${spinner phase}${text}
  '';
}