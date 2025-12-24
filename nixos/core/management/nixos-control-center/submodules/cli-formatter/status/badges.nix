{ lib, colors }:

let
  badge = type: text: 
    let badges = {
      ok = "${colors.green}[ OK ]${colors.reset}";
      error = "${colors.red}[ERROR]${colors.reset}";
      warn = "${colors.yellow}[WARN]${colors.reset}";
      info = "${colors.blue}[INFO]${colors.reset}";
      debug = "${colors.dim}[DEBUG]${colors.reset}";
    };
  in ''
    printf '%b\n' "${badges.${type}} ${text}"
  '';

in {
  badge = badge;
  success = text: badge "ok" text;
  error = text: badge "error" text;
  warning = text: badge "warn" text;
  info = text: badge "info" text;
  debug = text: badge "debug" text;
}