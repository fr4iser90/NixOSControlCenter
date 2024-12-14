{ pkgs, cfg }:

let
  # Python mit Tkinter
  pythonWithTk = pkgs.python3.withPackages (ps: with ps; [
    tkinter
  ]);
  
  # GUI-Programm als separates Script
  guiScript = pkgs.writeText "control-center-gui.py" ''
    import tkinter as tk
    from tkinter import ttk
    
    class ControlCenterGUI:
        def __init__(self):
            self.root = tk.Tk()
            self.root.title("NixOS Control Center")
            self.root.geometry("400x300")
            
            # Label
            ttk.Label(
                self.root, 
                text="NixOS Control Center", 
                font=("Helvetica", 16)
            ).pack(pady=20)
            
            # Status Button
            ttk.Button(
                self.root, 
                text="Check Service Status",
                command=self.check_status
            ).pack(pady=10)
            
        def check_status(self):
            ttk.Label(
                self.root, 
                text="Service is running on port ${toString cfg.port}",
                foreground="green"
            ).pack(pady=10)
            
        def run(self):
            self.root.mainloop()
    
    if __name__ == "__main__":
        app = ControlCenterGUI()
        app.run()
  '';

  # Wrapper-Script
  control-center-gui = pkgs.writeScriptBin "control-center-gui" ''
    #!${pkgs.bash}/bin/bash
    exec ${pythonWithTk}/bin/python3 ${guiScript}
  '';

in {
  inherit control-center-gui pythonWithTk;
}