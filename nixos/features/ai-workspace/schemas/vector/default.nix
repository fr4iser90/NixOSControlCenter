{ config, lib, pkgs, ... }:

let
  pythonWithPackages = pkgs.python3.withPackages (ps: with ps; [
    pymilvus
    setuptools
  ]);
in
{
  systemd.services.setup-milvus-schema = {
    description = "Setup Milvus Schema";
    after = [ "docker-milvus.service" ];
    wantedBy = [ "multi-user.target" ];
    
    path = [ pythonWithPackages ];  # Python mit pymilvus verfügbar machen
    
    script = ''
      until ${pkgs.curl}/bin/curl -s http://localhost:19530/v1/health; do
        echo "Waiting for Milvus..."
        sleep 2
      done
      
      ${pythonWithPackages}/bin/python3 ${./init.py}
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}