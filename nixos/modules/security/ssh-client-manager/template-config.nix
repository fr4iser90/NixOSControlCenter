{
  enable = false;
  credentialsFile = ".creds";
  keyType = "rsa";
  keyBits = 4096;
  fzf.theme.prompt = "→ ";
  fzf.theme.pointer = "▶";
  fzf.theme.marker = "✓";
  fzf.theme.header = "bold";
  fzf.keybindings = {
    "ctrl-x" = "delete";
    "ctrl-e" = "edit";
    "ctrl-n" = "new";
    "enter" = "connect";
  };
  fzf.preview.enable = true;
  fzf.preview.position = "right:40%";
}
