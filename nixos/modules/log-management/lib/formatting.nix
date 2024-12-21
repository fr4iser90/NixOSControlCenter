# Formatting utilities for the reporting module
{ lib, colors }:

with lib;

{
  # Basis Formatierung
  listItems = color: items: 
    concatMapStrings (item: ''
      echo -e "${color}  - ${item}${colors.reset}"
    '') items;

  header = color: text: ''
    echo -e "\n${color}=== ${text} ===${colors.reset}"
  '';

  # Status Formatierung
  success = text: ''
    echo -e "${colors.green}✓ ${text}${colors.reset}"
  '';

  error = text: ''
    echo -e "${colors.red}✗ ${text}${colors.reset}"
  '';

  warning = text: ''
    echo -e "${colors.yellow}! ${text}${colors.reset}"
  '';

  info = text: ''
    echo -e "${colors.blue}ℹ ${text}${colors.reset}"
  '';

  # Spezielle Formatierung
  section = text: ''
    printf '%b' "${colors.cyan}=== ${text} ===${colors.reset}\n"
  '';

  subsection = text: ''
    echo -e "\n${text}:"
  '';

  highlight = text: ''
    echo -e "${colors.bold}${text}${colors.reset}"
  '';

  table = headers: rows: let
    # Tabellen-Formatierung hier
  in ''
    # TODO: Implementiere Tabellen-Formatierung
  '';

  # Detail Level Formatierung
  detailLevel = level: text: ''
    echo -e "${colors.dim}[${level}] ${text}${colors.reset}"
  '';

  # Progress Formatierung
  progress = current: total: let 
    width = 30;
    filled = width * current / total;
    empty = width - filled;
  in ''
    echo -e "[${colors.cyan}${"#" * filled}${colors.dim}${"-" * empty}${colors.reset}] ${toString (current * 100 / total)}%"
  '';

  # Key-Value Paare
  keyValue = key: value: ''
    echo -e "${key}: ${value}"
  '';

  # Status-Badges
  badge = type: text: 
    let badge = {
      ok = "${colors.green}[ OK ]${colors.reset}";
      error = "${colors.red}[ERROR]${colors.reset}";
      warn = "${colors.yellow}[WARN]${colors.reset}";
      info = "${colors.blue}[INFO]${colors.reset}";
      debug = "${colors.dim}[DEBUG]${colors.reset}";
    };
  in ''
    echo -e "${badge.${type}} ${text}"
  '';

  # Trennlinien
  separator = char: width: ''
    echo -e ""
  '';

  # Code-Block
  codeBlock = text: ''
    echo -e "${colors.dim}```${colors.reset}\n${text}\n${colors.dim}```${colors.reset}"
  '';
}