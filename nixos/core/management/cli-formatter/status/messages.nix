{ lib, colors }:

{
  success = text: ''
    printf '%b\n' "${colors.green}${text}${colors.reset}"
  '';

  error = text: ''
    printf '%b\n' "${colors.red}${text}${colors.reset}"
  '';

  warning = text: ''
    printf '%b\n' "${colors.yellow}${text}${colors.reset}"
  '';

  info = text: ''
    printf '%b\n' "${colors.blue}${text}${colors.reset}"
  '';

  loading = text: ''
    printf '%b\n' "${colors.cyan}${text}${colors.reset}"
  '';

  detailLevel = level: text: ''
    printf '%b\n' "${colors.dim}[${level}] ${text}${colors.reset}"
  '';
}