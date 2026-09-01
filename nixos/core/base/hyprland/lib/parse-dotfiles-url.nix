# Parse dotfilesUrl into git clone metadata for collection fetch.
url:
let
  stripSlash = s: builtins.replaceStrings [ "/" ] [ "" ] s;
  ghTree = builtins.match "https://github.com/([^/]+)/([^/]+)/tree/([^/]+).*" url;
  ghPlain = builtins.match "https://github.com/([^/]+)/([^/]+)/?.*" url;
  cbPlain = builtins.match "https://codeberg.org/([^/]+)/([^/]+)/?.*" url;
in
  if url == null || url == "" then {
    cloneUrl = "";
    ref = "main";
  }
  else if ghTree != null then {
    cloneUrl = "https://github.com/${builtins.elemAt ghTree 0}/${stripSlash (builtins.elemAt ghTree 1)}.git";
    ref = builtins.elemAt ghTree 2;
  }
  else if ghPlain != null then {
    cloneUrl = "https://github.com/${builtins.elemAt ghPlain 0}/${stripSlash (builtins.elemAt ghPlain 1)}.git";
    ref = "main";
  }
  else if cbPlain != null then {
    cloneUrl = "https://codeberg.org/${builtins.elemAt cbPlain 0}/${stripSlash (builtins.elemAt cbPlain 1)}.git";
    ref = "main";
  }
  else {
    cloneUrl = url;
    ref = "main";
  }
