{ lib, colors }:

with lib;
{
  # Grundlegende Abstände
  indent = level: text: ''
    printf '%b\n' "${concatStrings (genList (_: " ") level)}${text}"
  '';

  newline = ''
    printf '\n'
  '';

  # Rahmen und Boxen
  frame = text: let
    width = stringLength text + 4;
  in ''
    printf '%b\n' "${colors.cyan}┌${concatStrings (genList (_: "─") width)}┐${colors.reset}"
    printf '%b\n' "${colors.cyan}│  ${text}  │${colors.reset}"
    printf '%b\n' "${colors.cyan}└${concatStrings (genList (_: "─") width)}┘${colors.reset}"
  '';

  # Gruppierung
  group = title: content: ''
    printf '%b\n' "${colors.cyan}=== ${title} ===${colors.reset}"
    printf '%b\n' "${content}"
  '';

  # Abschnitte
  section = {
    main = title: ''
      printf '\n%b\n' "${colors.bold}${title}${colors.reset}"
      printf '%b\n' "${colors.dim}${concatStrings (genList (_: "─") (stringLength title))}${colors.reset}"
    '';

    sub = title: ''
      printf '\n%b\n' "${colors.cyan}${title}${colors.reset}:"
    '';
  };

  # Abstände
  spacing = {
    small = newline;
    medium = ''
      printf '\n\n'
    '';
    large = ''
      printf '\n\n\n'
    '';
  };

  # Separator
  separator = char: width: ''
    printf '%b\n' "${concatStrings (genList (_: char) width)}"
  '';

  # Container
  container = {
    simple = content: ''
      printf '%b\n' "┌──────────────────┐"
      printf '%b\n' "│${content}│"
      printf '%b\n' "└──────────────────┘"
    '';

    titled = title: content: ''
      printf '%b\n' "┌── ${title} ───┐"
      printf '%b\n' "│${content}│"
      printf '%b\n' "└──────────────┘"
    '';
  };
}