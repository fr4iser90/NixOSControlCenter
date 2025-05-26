{ pkgs, lib, ... }:
{
  # Python 3.12 (neueste Version)
  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    # Test dependencies
    pytest
    pytest-asyncio
    pytest-cov
    pytest-mock
    httpx
    
    # Logging und Formatierung
    structlog
    colorama
    
    # Monitoring und System
    psutil
    requests
    pillow
    
    # Database dependencies
    sqlalchemy
    asyncpg
    alembic
    psycopg2
    
    # Development Tools
    black
    mypy
    pylint
    ipython
    jupyter
    notebook
    
    # Web Development
    fastapi
    uvicorn
    pydantic
    pydantic-settings
    python-multipart
    
    # Security
    cryptography
    python-jose
    passlib
    bcrypt
    
    # Utilities
    python-dotenv
    py-cpuinfo
    speedtest-cli
    pyyaml
    email-validator
  ]);
}
