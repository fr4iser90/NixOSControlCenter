{ lib, pkgs }:

let
  # Basis-Port für SPICE-Verbindungen
  basePort = 5900;
  maxPort = 5999;  # Maximum port to try

  # Prüft ob ein Port verfügbar ist
  isPortFree = port: "${pkgs.netcat}/bin/nc -z localhost ${toString port} 2>/dev/null";

  # Generiert eine SPICE-URL
  makeSpiceUrl = port: "spice://localhost:${toString port}";

in {
  # Exportierte Funktionen
  vmPortManager = name: ''
    # Port-Check Funktion
    check_port() {
      ${isPortFree "$1"}
      if [ $? -eq 0 ]; then
        return 1  # Port belegt
      else
        return 0  # Port frei
      fi
    }

    # Finde freien Port
    find_free_port() {
      local port=${toString basePort}
      while [ $port -le ${toString maxPort} ]; do
        check_port $port
        if [ $? -eq 0 ]; then
          echo $port
          return 0
        fi
        port=$((port + 1))
      done
      echo "Error: No free ports available between ${toString basePort} and ${toString maxPort}" >&2
      return 1
    }

    # Replace (not append) tracking entry for this VM — avoids stale multi-port noise
    track_vm_port() {
      local vm_name="$1"
      local port="$2"
      local tracking_file="''${XDG_RUNTIME_DIR:-/tmp}/ncc-vm-ports"
      mkdir -p "$(dirname "$tracking_file")" 2>/dev/null || true
      if [ -f "$tracking_file" ]; then
        grep -v "^''${vm_name}:" "$tracking_file" > "''${tracking_file}.tmp" 2>/dev/null || true
        mv "''${tracking_file}.tmp" "$tracking_file" 2>/dev/null || true
      fi
      echo "$vm_name:$port" >> "$tracking_file"
    }

    cleanup_vm_port() {
      local vm_name="$1"
      local tracking_file="''${XDG_RUNTIME_DIR:-/tmp}/ncc-vm-ports"
      if [ -f "$tracking_file" ]; then
        grep -v "^''${vm_name}:" "$tracking_file" > "''${tracking_file}.tmp" 2>/dev/null || true
        mv "''${tracking_file}.tmp" "$tracking_file" 2>/dev/null || true
      fi
    }

    # Hauptlogik — no stale "Active VMs" dump (live QEMU check lives in vm.nix)
    VM_PORT=$(find_free_port)
    if [ $? -ne 0 ]; then
      echo "❌ $VM_PORT" >&2
      exit 1
    fi

    track_vm_port "${name}" "$VM_PORT"
    trap 'cleanup_vm_port "${name}"' EXIT

    # Nur den Port auf stdout
    echo -n "$VM_PORT"
  '';

  # Helper für URLs
  makeSpiceUrl = port: makeSpiceUrl port;
}