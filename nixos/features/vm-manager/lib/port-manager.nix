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

    # VM Port Tracking
    track_vm_port() {
      local vm_name="$1"
      local port="$2"
      local tracking_file="/tmp/vm_ports"
      echo "$vm_name:$port" >> "$tracking_file"
    }

    # Liste aktive VMs
    list_active_vms() {
      if [ -f "/tmp/vm_ports" ]; then
        echo "Active VMs:" >&2
        echo "===========" >&2
        while IFS=: read -r name port; do
          echo "🖥️  $name: spice://localhost:$port" >&2
        done < "/tmp/vm_ports"
      fi
    }

    # Cleanup Funktion
    cleanup_vm_port() {
      local vm_name="$1"
      local tracking_file="/tmp/vm_ports"
      if [ -f "$tracking_file" ]; then
        sed -i "/$vm_name:/d" "$tracking_file"
      fi
    }

    # Hauptlogik
    VM_PORT=$(find_free_port)
    if [ $? -ne 0 ]; then
      echo "❌ $VM_PORT" >&2
      exit 1
    fi
    
    track_vm_port "${name}" "$VM_PORT"
    
    # Zeige aktive VMs auf stderr
    list_active_vms >&2
    
    # Cleanup beim Beenden
    trap 'cleanup_vm_port "${name}"' EXIT
    
    # Nur den Port auf stdout
    echo -n "$VM_PORT"
  '';

  # Helper für URLs
  makeSpiceUrl = port: makeSpiceUrl port;
}