# development/web.nix
{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Web Development Tools
    vscode                 # IDE for web development
    nodejs                 # JavaScript runtime for backend development
    yarn                   # Package manager for JavaScript projects
    #npm                    # Default Node.js package manager
    deno                   # Alternative runtime for modern JavaScript/TypeScript
    pnpm                   # Faster alternative to npm
    maven
    xorg.libX11
    xorg.libXtst
    gtk3  

    # Web Servers
    nginx                  # Web server for testing and deployment
    apacheHttpd            # Alternative web server

    # Databases
    postgresql             # Relational database
    sqlite                 # Lightweight database for local projects
    redis                  # In-memory database for caching

    # API Development & Testing
    postman                # GUI tool for API testing
    httpie                 # CLI tool for testing HTTP requests
    curl                   # Versatile HTTP client for testing APIs

    # Frontend Tools
    sass                   # CSS preprocessor
    less                   # CSS preprocessor
    tailwindcss            # Utility-first CSS framework
    eslint                 # Linter for JavaScript and TypeScript
    #prettier               # Code formatter

    # Backend Tools
    #express                # Lightweight web framework for Node.js
    #fastify                # High-performance Node.js framework
  ];
}
