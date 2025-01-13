{ lib, ... }:
{
  setupUserCreds = user: ''
    if [ ! -f /home/${user}/.creds ]; then
      install -m 600 -o ${user} -g ${user} /dev/null /home/${user}/.creds
    fi
  '';
}
