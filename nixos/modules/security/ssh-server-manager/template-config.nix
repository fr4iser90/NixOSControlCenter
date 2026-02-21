{
  enable = false;
  banner = ''
    ===============================================
    Password authentication is disabled by default.

    If you don't have a public key set up:
    1. Request access: ssh-request-access USERNAME "reason"
    2. Wait for admin approval
    3. Or ask admin to run: ssh-grant-access USERNAME

    For help: ssh-list-requests (admins only)
    ===============================================
  '';
}
