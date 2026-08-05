{ lib }:

# Auto-discovered mechanical / advisory / complex eval-warning rules.
# Each rule:
#   id            - stable identifier
#   class         - mechanical | advisory | complex
#   matchContains - substring gate (fast filter)
#   sedExtract    - sed -n expression; prints fingerprint or empty
#   hint          - optional user-facing tip
[
  {
    id = "nixpkgs.xorg-attr-rename";
    class = "mechanical";
    matchContains = "The xorg package set has been deprecated";
    sedExtract = "s/.*'xorg\\.\\([^']*\\)' has been renamed to '\\([^']*\\)'.*/xorg.\\1→\\2/p";
    hint = "Replace pkgs.xorg.<old> / xorg.<old> with top-level pkgs.<new>";
  }
  {
    id = "nixpkgs.generic-renamed";
    class = "mechanical";
    matchContains = "has been renamed to";
    # Catch-all for "'foo' has been renamed to 'bar'" (skip if already matched xorg)
    sedExtract = "s/.*'\\([^']*\\)' has been renamed to '\\([^']*\\)'.*/\\1→\\2/p";
    hint = "Apply the rename shown in the warning";
  }
]
