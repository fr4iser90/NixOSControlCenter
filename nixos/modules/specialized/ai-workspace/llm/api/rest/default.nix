# llm/api/rest/default.nix
{ config, lib, pkgs, ... }:

let
  # Python Environment
  python-env = pkgs.python3.withPackages (ps: with ps; [
    fastapi
    uvicorn
    pydantic
    requests
    python-dotenv
    psycopg2
    pymilvus
    setuptools
    httpx
    python-multipart 
  ]);

  # Service Files
  service-files = pkgs.symlinkJoin {
    name = "ai-api-files";
    paths = [
      (pkgs.writeTextDir "service.py" (builtins.readFile ./service.py))
      (pkgs.writeTextDir "routers.py" (builtins.readFile ./routers.py))
      # Schemas
      (pkgs.writeTextDir "endpoints/schemas/models.py" (builtins.readFile ./endpoints/schemas/models.py))
      (pkgs.writeTextDir "endpoints/schemas/chat.py" (builtins.readFile ./endpoints/schemas/chat.py))
      (pkgs.writeTextDir "endpoints/schemas/model_customization.py" (builtins.readFile ./endpoints/schemas/model_customization.py))
      
      # CRUD Endpoints
      # Chat  
      (pkgs.writeTextDir "endpoints/crud/chat/create.py" (builtins.readFile ./endpoints/crud/chat/create.py))
      (pkgs.writeTextDir "endpoints/crud/chat/read.py" (builtins.readFile ./endpoints/crud/chat/read.py))
      
      # Models
      (pkgs.writeTextDir "endpoints/crud/models/create.py" (builtins.readFile ./endpoints/crud/models/create.py))
      (pkgs.writeTextDir "endpoints/crud/models/read.py" (builtins.readFile ./endpoints/crud/models/read.py))
      (pkgs.writeTextDir "endpoints/crud/models/update.py" (builtins.readFile ./endpoints/crud/models/update.py))
      (pkgs.writeTextDir "endpoints/crud/models/delete.py" (builtins.readFile ./endpoints/crud/models/delete.py))

      # Fine Tuning
      (pkgs.writeTextDir "endpoints/crud/model_customization/create.py" (builtins.readFile ./endpoints/crud/model_customization/create.py))
      (pkgs.writeTextDir "endpoints/crud/model_customization/read.py" (builtins.readFile ./endpoints/crud/model_customization/read.py))
      (pkgs.writeTextDir "endpoints/crud/model_customization/delete.py" (builtins.readFile ./endpoints/crud/model_customization/delete.py))

      # Vector Endpoints
      (pkgs.writeTextDir "endpoints/vector/collections.py" (builtins.readFile ./endpoints/vector/collections.py))
      (pkgs.writeTextDir "endpoints/vector/embeddings.py" (builtins.readFile ./endpoints/vector/embeddings.py))
      #(pkgs.writeTextDir "endpoints/vector/store.py" (builtins.readFile ./endpoints/vector/store.py))
      # Code Endpoints
      #(pkgs.writeTextDir "endpoints/code/analysis.py" (builtins.readFile ./endpoints/code/analysis.py))
      #(pkgs.writeTextDir "endpoints/code/git.py" (builtins.readFile ./endpoints/code/git.py))
      # System Endpoints
      #(pkgs.writeTextDir "endpoints/system/auth.py" (builtins.readFile ./endpoints/system/auth.py))
      #(pkgs.writeTextDir "endpoints/system/monitoring.py" (builtins.readFile ./endpoints/system/monitoring.py))
    ];
  };

  # API Service Script
  api-service = pkgs.writeScriptBin "ai-api" ''
    #!${pkgs.bash}/bin/bash
    export PYTHONPATH=${service-files}:$PYTHONPATH
    exec ${python-env}/bin/python ${service-files}/service.py
  '';

in {
  # System-Konfiguration
  environment.systemPackages = [ python-env api-service ];

  # Systemd Service
  systemd.services.ai-api = {
    description = "AI Workspace API";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${api-service}/bin/ai-api";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "ai-service";
      Group = "ai-service";
      WorkingDirectory = "${service-files}";
      Environment = [
        "PYTHONPATH=${service-files}"
        "PYTHONUNBUFFERED=1"
      ];
    };
  };

  # Erstelle Service-User
  users.users.ai-service = {
    isSystemUser = true;
    group = "ai-service";
    description = "AI API service user";
  };

  users.groups.ai-service = {};
}