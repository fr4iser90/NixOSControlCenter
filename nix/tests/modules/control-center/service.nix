{ pkgs, cfg, pythonWithTk }:

{
  description = "NixOS Control Center Service";
  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" ];
  
  serviceConfig = {
    Type = "simple";
    ExecStart = "${pythonWithTk}/bin/python3 -c 'print(\"Control Center running\")'";
    Restart = "on-failure";
  };
}