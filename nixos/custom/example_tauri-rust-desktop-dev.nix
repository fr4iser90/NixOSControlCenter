# Example: Tauri desktop development on NixOS — Rust toolchain (rustup) + system libs for WebView/GTK.
# nixos/custom/default.nix skips example_*.nix — import explicitly, e.g.:
#   imports = [ ./custom/example_tauri-rust-desktop-dev.nix ];
#
# Maps roughly to https://tauri.app/start/prerequisites/#linux (WebKitGTK 4.1, SSL, tray, libxdo, …).
# Tauri 2 may need more crates later — extend the `tauriPkgConfig` list if `pkg-config` still complains.
#
# After `nixos-rebuild switch`, as your dev user (once per account):
#   rustup default stable
#   rustup component add rustfmt clippy   # optional
#   cargo --version && rustc --version
#
# Node / pnpm are not included here — use nixpkgs `nodejs`, `corepack enable`, or a project flake.
# Reproducible alternative to rustup: fenix / rust-overlay in a flake devShell (not this module).
#
# --- glib-sys / pkg-config on NixOS ---
# If you see: `PKG_CONFIG_PATH=/usr/lib/pkgconfig` and `Package glib-2.0 was not found`:
# something (shell, IDE, direnv, ~/.cargo/config.toml) forces FHS paths. On NixOS there is no
# glib-2.0.pc under /usr. This module sets PKG_CONFIG_PATH to nix store `*.dev` paths.
# Still broken? Run `echo $PKG_CONFIG_PATH`, remove bad exports from ~/.zshrc etc., re-login.
#
# WebKitGTK 4.1 in nixpkgs zieht `libsoup-3.0` (nicht Soup 2) — daher `libsoup_3`/`libsoup_3.dev`, kein
# `permittedInsecurePackages` und kein libsoup_2_4 nötig.
{ config, lib, pkgs, ... }:

let
  # Paths where *.pc files live (glib-sys, gtk-sys, cairo-sys, …)
  tauriPkgConfig = lib.makeSearchPath "lib/pkgconfig" (
    with pkgs;
    [
      glib.dev
      gtk3.dev
      cairo.dev
      pango.dev
      gdk-pixbuf.dev
      atk.dev
      at-spi2-core.dev
      harfbuzz.dev
      fribidi.dev
      openssl.dev
      webkitgtk_4_1.dev
      libsoup_3.dev
      libxml2.dev
      sqlite.dev
      dbus.dev
      fontconfig.dev
      freetype.dev
      zlib.dev
    ]
  );
in
{
  environment.systemPackages = with pkgs; [
    # Rust (matches upstream “install rustup”; you still run `rustup default stable` once)
    rustup
    rust-analyzer

    # C toolchain / native deps built by many crates
    gcc
    gnumake
    cmake
    pkg-config

    # TLS / crypto (openssl-sys, etc.)
    openssl

    # GLib (runtime + pulls dev for local use; pkg-config still needs tauriPkgConfig below)
    glib

    # WebKitGTK + GTK3 (Tauri Linux desktop WebView); Soup 3 matches webkit2gtk-4.1.pc (Requires: libsoup-3.0)
    webkitgtk_4_1
    gtk3
    libsoup_3

    # Tray / status icon (Debian: libayatana-appindicator3-dev)
    libayatana-appindicator

    # SVG (Debian: librsvg2-dev)
    librsvg

    # Global shortcuts / libxdo (Debian: libxdo-dev)
    xdotool

    # Small utilities often assumed on PATH by scripts / tutorials
    curl
    wget
    file
  ];

  # So `cargo build` / `pnpm tauri dev` find glib-2.0.pc etc. (overrides bogus /usr/lib/pkgconfig).
  environment.sessionVariables = {
    PKG_CONFIG_PATH = tauriPkgConfig;
  };
}
