{ lib, colors }:

{
  box = text: let
    line = "─";
    corner = "│";
    width = 60;
    padding = 2;
    contentWidth = width - (padding * 2) - 2;
  in ''
    echo -e "${colors.cyan}┌${"${line}" * width}┐${colors.reset}"
    echo -e "${colors.cyan}${corner}${" " * padding}${text}${" " * (contentWidth - (lib.stringLength text))}${" " * padding}${corner}${colors.reset}"
    echo -e "${colors.cyan}└${"${line}" * width}┘${colors.reset}"
  '';
}