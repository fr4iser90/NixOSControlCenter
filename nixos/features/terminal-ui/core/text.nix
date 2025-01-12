{ lib, colors }:

with lib;
{
  # Basis Text Formatierung
  header = text: ''
    printf '%b\n' "\n${colors.blue}=== ${text} ===${colors.reset}"
  '';

  subHeader = text: ''
    printf '%b\n' "\n${colors.cyan}--- ${text} ---${colors.reset}"
  '';
  
  section = text: ''
    printf '%b\n' "${colors.cyan}=== ${text} ===${colors.reset}"
  '';

  subsection = text: ''
    printf '%b\n' "\n${text}:"
  '';

  paragraph = text: ''
    printf '%b\n' "\n${text}\n"
  '';

  indented = level: text: ''
    printf '%b\n' "${"  " * level}${text}"
  '';

  highlight = text: ''
    printf '%b\n' "${colors.bold}${text}${colors.reset}"
  '';

  info = text: ''
    printf '%b\n' "${colors.cyan}${text}${colors.reset}"
  '';

  codeBlock = text: ''
    printf '%b\n' "${colors.dim}\`\`\`${colors.reset}\n${text}\n${colors.dim}\`\`\`${colors.reset}"
  '';

  keyValue = key: value: ''
    printf '%b\n' "${key}: ${value}"
  '';

  separator = width: ''
    printf '%*s\n' "$width" " " | tr ' ' '-'
  '';

  tables = {
    keyValue = key: value: ''
      printf '%b\n' "  ${colors.cyan}${key}${colors.reset}: ${value}"
    '';
  };
}