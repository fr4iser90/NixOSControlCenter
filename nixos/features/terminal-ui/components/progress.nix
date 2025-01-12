{ lib, colors }:

{
  progress = current: total: let 
    width = 30;
    filled = width * current / total;
    empty = width - filled;
  in ''
    printf '%b\n' "[${colors.cyan}${"#" * filled}${colors.dim}${"-" * empty}${colors.reset}] ${toString (current * 100 / total)}%"
  '';

  progressBar = {
    simple = progress: total: let
      percentage = progress * 100 / total;
      width = 50;
      filled = width * progress / total;
      empty = width - filled;
    in ''
      printf '\r%b' "[${colors.cyan}${"#" * filled}${colors.dim}${"-" * empty}${colors.reset}] ${toString percentage}%"
    '';

    detailed = progress: total: text: let
      percentage = progress * 100 / total;
      width = 30;
      filled = width * progress / total;
      empty = width - filled;
    in ''
      printf '\r%b' "${text} [${colors.cyan}${"#" * filled}${colors.dim}${"-" * empty}${colors.reset}] ${toString percentage}% (${toString progress}/${toString total})"
    '';
  };

  spinner = phase: let
    frames = ["⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"];
    index = phase % (builtins.length frames);
  in ''
    printf '\r%b' "${frames.[index]} "
  '';
}