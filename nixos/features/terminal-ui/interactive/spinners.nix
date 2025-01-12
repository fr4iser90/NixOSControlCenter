{ lib, colors }:

{
  # Klassischer Spinner
  basic = phase: let
    frames = [ "|" "/" "-" "\\" ];
    index = phase % (builtins.length frames);
  in ''
    printf '\r%b' "${frames.[index]} "
  '';

  # Dots Spinner
  dots = phase: let
    frames = [ "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" ];
    index = phase % (builtins.length frames);
  in ''
    printf '\r%b' "${frames.[index]} "
  '';

  # Braille Spinner
  braille = phase: let
    frames = [ "⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷" ];
    index = phase % (builtins.length frames);
  in ''
    printf '\r%b' "${frames.[index]} "
  '';

  # Line Spinner
  line = phase: let
    frames = [ "─" "\\" "|" "/" ];
    index = phase % (builtins.length frames);
  in ''
    printf '\r%b' "${frames.[index]} "
  '';

  # Mit Text
  withText = type: text: phase: let
    spinner = builtins.getAttr type self;
  in ''
    ${spinner phase}${text}
  '';
}