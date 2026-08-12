{
  # enable = SSH server on this host (sshd + unlock tools)
  enable = false;
  _version = "2.0";

  passwordAuthentication = true;
  permitRootLogin = "yes";
  workflow.enable = false;

  # Outbound connection manager (former ssh-manager)
  client.enable = false;
  client.credentialsFile = ".creds";
  client.keyType = "rsa";
  client.keyBits = 4096;
  client.fzf.theme.prompt = "→ ";
  client.fzf.theme.pointer = "▶";
  client.fzf.theme.marker = "✓";
  client.fzf.theme.header = "bold";
  client.fzf.keybindings = {
    "ctrl-x" = "delete";
    "ctrl-e" = "edit";
    "ctrl-n" = "new";
    "enter" = "connect";
  };
  client.fzf.preview.enable = true;
  client.fzf.preview.position = "right:40%";

  banner = ''
    ===============================================
    NCC SSH server

    Bootstrap: password auth may still be on (safe default).
    After keys work: sudo ncc ssh lockdown
    Temporary reopen: ncc ssh temp-open USER | grant-access USER
    ===============================================
  '';
}
