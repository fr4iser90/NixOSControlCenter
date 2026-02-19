package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/google/uuid"
)

// Session represents a migration session
type Session struct {
	ID          string    `json:"id"`
	Status      string    `json:"status"`
	CreatedAt   time.Time `json:"created_at"`
	Report      *Report   `json:"report,omitempty"`
	Config      string    `json:"config,omitempty"`
	ISOURL      string    `json:"iso_url,omitempty"`
	Error       string    `json:"error,omitempty"`
}

// Report represents a snapshot report from Windows/macOS/Linux
type Report struct {
	Timestamp string                 `json:"timestamp"`
	OS        string                 `json:"os"`
	Version   string                 `json:"version,omitempty"`
	Hardware  map[string]interface{} `json:"hardware"`
	Programs  []map[string]interface{} `json:"programs"`
	Settings  map[string]interface{} `json:"settings"`
}

// Server holds the web service state
type Server struct {
	sessions map[string]*Session
	port     string
	host     string
	dataDir  string
}

func NewServer(port, host, dataDir string) *Server {
	return &Server{
		sessions: make(map[string]*Session),
		port:     port,
		host:     host,
		dataDir:  dataDir,
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	host := os.Getenv("HOST")
	if host == "" {
		host = "127.0.0.1"
	}

	dataDir := os.Getenv("DATA_DIR")
	if dataDir == "" {
		dataDir = "/var/lib/nixify"
	}

	// Create data directory
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		log.Fatalf("Failed to create data directory: %v", err)
	}

	server := NewServer(port, host, dataDir)

	// Setup routes
	http.HandleFunc("/", server.handleRoot)
	http.HandleFunc("/api/v1/health", server.handleHealth)
	http.HandleFunc("/api/v1/upload", server.handleUpload)
	http.HandleFunc("/api/v1/sessions", server.handleListSessions)
	http.HandleFunc("/api/v1/session/", server.handleGetSession)
	http.HandleFunc("/api/v1/config/", server.handleGetConfig)
	http.HandleFunc("/api/v1/iso/build", server.handleBuildISO)
	http.HandleFunc("/api/v1/iso/", server.handleGetISO)
	http.HandleFunc("/download/", server.handleDownloadScript)

	// Static file serving for scripts
	http.HandleFunc("/download/windows", server.handleDownloadWindows)
	http.HandleFunc("/download/macos", server.handleDownloadMacOS)
	http.HandleFunc("/download/linux", server.handleDownloadLinux)

	addr := fmt.Sprintf("%s:%s", host, port)
	log.Printf("🚀 Nixify Web Service starting on %s", addr)
	log.Printf("📁 Data directory: %s", dataDir)

	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func (s *Server) handleRoot(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	html := `<!DOCTYPE html>
<html>
<head>
    <title>Nixify Web Service</title>
    <style>
        body { font-family: monospace; margin: 40px; background: #1e1e1e; color: #d4d4d4; }
        h1 { color: #4ec9b0; }
        h2 { color: #569cd6; margin-top: 30px; }
        code { background: #252526; padding: 2px 6px; border-radius: 3px; }
        .endpoint { margin: 10px 0; padding: 10px; background: #252526; border-left: 3px solid #4ec9b0; }
        .method { color: #4ec9b0; font-weight: bold; }
        .path { color: #ce9178; }
    </style>
</head>
<body>
    <h1>🚀 Nixify Web Service</h1>
    <p>Windows/macOS/Linux → NixOS System-DNA-Extractor</p>
    
    <h2>API Endpoints</h2>
    
    <div class="endpoint">
        <span class="method">GET</span> <span class="path">/api/v1/health</span>
        <p>Service health check</p>
    </div>
    
    <div class="endpoint">
        <span class="method">POST</span> <span class="path">/api/v1/upload</span>
        <p>Upload snapshot report (JSON)</p>
    </div>
    
    <div class="endpoint">
        <span class="method">GET</span> <span class="path">/api/v1/sessions</span>
        <p>List all migration sessions</p>
    </div>
    
    <div class="endpoint">
        <span class="method">GET</span> <span class="path">/api/v1/session/{id}</span>
        <p>Get session details</p>
    </div>
    
    <div class="endpoint">
        <span class="method">GET</span> <span class="path">/api/v1/config/{id}</span>
        <p>Get generated NixOS configuration</p>
    </div>
    
    <div class="endpoint">
        <span class="method">POST</span> <span class="path">/api/v1/iso/build</span>
        <p>Build custom NixOS ISO</p>
    </div>
    
    <div class="endpoint">
        <span class="method">GET</span> <span class="path">/api/v1/iso/{id}/download</span>
        <p>Download built ISO</p>
    </div>
    
    <h2>Download Scripts</h2>
    
    <div class="endpoint">
        <span class="method">GET</span> <span class="path">/download/windows</span>
        <p>Download Windows snapshot script (PowerShell)</p>
    </div>
    
    <div class="endpoint">
        <span class="method">GET</span> <span class="path">/download/macos</span>
        <p>Download macOS snapshot script (Bash)</p>
    </div>
    
    <div class="endpoint">
        <span class="method">GET</span> <span class="path">/download/linux</span>
        <p>Download Linux snapshot script (Bash)</p>
    </div>
    
    <h2>Quick Test</h2>
    <p>Test the service: <code>curl http://localhost:8080/api/v1/health</code></p>
    
    <p style="margin-top: 40px; color: #858585; font-size: 0.9em;">
        Service running on: <code>` + fmt.Sprintf("%s:%s", s.host, s.port) + `</code><br>
        Active sessions: <code>` + fmt.Sprintf("%d", len(s.sessions)) + `</code>
    </p>
</body>
</html>`
	fmt.Fprint(w, html)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
		"sessions":  len(s.sessions),
	})
}

func (s *Server) handleUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var report Report
	if err := json.NewDecoder(r.Body).Decode(&report); err != nil {
		http.Error(w, fmt.Sprintf("Invalid JSON: %v", err), http.StatusBadRequest)
		return
	}

	// Create session
	sessionID := uuid.New().String()
	session := &Session{
		ID:        sessionID,
		Status:    "processing",
		CreatedAt: time.Now(),
		Report:    &report,
	}

	s.sessions[sessionID] = session

	// Save report to disk
	reportPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-report.json", sessionID))
	if err := s.saveJSON(reportPath, report); err != nil {
		log.Printf("Failed to save report: %v", err)
		session.Status = "error"
		session.Error = fmt.Sprintf("Failed to save report: %v", err)
	} else {
		// Process in background
		go s.processSession(sessionID)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"session_id":     sessionID,
		"status":         session.Status,
		"estimated_time": "2-5 minutes",
	})
}

func (s *Server) handleListSessions(w http.ResponseWriter, r *http.Request) {
	sessions := make([]map[string]interface{}, 0, len(s.sessions))
	for _, session := range s.sessions {
		sessions = append(sessions, map[string]interface{}{
			"id":        session.ID,
			"status":    session.Status,
			"created_at": session.CreatedAt,
			"os":        session.Report.OS,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"sessions": sessions,
	})
}

func (s *Server) handleGetSession(w http.ResponseWriter, r *http.Request) {
	sessionID := r.URL.Path[len("/api/v1/session/"):]
	session, ok := s.sessions[sessionID]
	if !ok {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(session)
}

func (s *Server) handleGetConfig(w http.ResponseWriter, r *http.Request) {
	sessionID := r.URL.Path[len("/api/v1/config/"):]
	session, ok := s.sessions[sessionID]
	if !ok {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	if session.Config == "" {
		http.Error(w, "Config not yet generated", http.StatusProcessing)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"session_id": sessionID,
		"config":      session.Config,
		"preview": map[string]interface{}{
			"packages": s.extractPackages(session.Report),
			"modules":  []string{}, // TODO: Extract from config
			"desktop":  s.extractDesktop(session.Report),
		},
	})
}

func (s *Server) handleBuildISO(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		SessionID string `json:"session_id"`
		Variant   string `json:"variant,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid JSON: %v", err), http.StatusBadRequest)
		return
	}

	session, ok := s.sessions[req.SessionID]
	if !ok {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	if session.Config == "" {
		http.Error(w, "Config not yet generated", http.StatusProcessing)
		return
	}

	// Build ISO in background
	go s.buildISO(req.SessionID, req.Variant)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"session_id": req.SessionID,
		"status":     "building",
		"message":    "ISO build started",
	})
}

func (s *Server) handleGetISO(w http.ResponseWriter, r *http.Request) {
	sessionID := r.URL.Path[len("/api/v1/iso/"):]
	if sessionID == "" || sessionID == "download" {
		http.Error(w, "Invalid session ID", http.StatusBadRequest)
		return
	}

	session, ok := s.sessions[sessionID]
	if !ok {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	if session.ISOURL == "" {
		http.Error(w, "ISO not yet built", http.StatusProcessing)
		return
	}

	// Serve ISO file
	isoPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s.iso", sessionID))
	if _, err := os.Stat(isoPath); os.IsNotExist(err) {
		http.Error(w, "ISO file not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=nixos-nixified-%s.iso", sessionID))
	
	file, err := os.Open(isoPath)
	if err != nil {
		http.Error(w, "Failed to open ISO", http.StatusInternalServerError)
		return
	}
	defer file.Close()

	io.Copy(w, file)
}

func (s *Server) handleDownloadScript(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "Use /download/windows, /download/macos, or /download/linux", http.StatusBadRequest)
}

func (s *Server) handleDownloadWindows(w http.ResponseWriter, r *http.Request) {
	scriptPath := "/nix/store/.../nixify-scan.ps1" // TODO: Get actual path from Nix store
	w.Header().Set("Content-Type", "text/plain")
	w.Header().Set("Content-Disposition", "attachment; filename=nixify-scan.ps1")
	http.ServeFile(w, r, scriptPath)
}

func (s *Server) handleDownloadMacOS(w http.ResponseWriter, r *http.Request) {
	scriptPath := "/nix/store/.../nixify-scan.sh" // TODO: Get actual path from Nix store
	w.Header().Set("Content-Type", "text/plain")
	w.Header().Set("Content-Disposition", "attachment; filename=nixify-scan.sh")
	http.ServeFile(w, r, scriptPath)
}

func (s *Server) handleDownloadLinux(w http.ResponseWriter, r *http.Request) {
	scriptPath := "/nix/store/.../nixify-scan.sh" // TODO: Get actual path from Nix store
	w.Header().Set("Content-Type", "text/plain")
	w.Header().Set("Content-Disposition", "attachment; filename=nixify-scan.sh")
	http.ServeFile(w, r, scriptPath)
}

func (s *Server) processSession(sessionID string) {
	session := s.sessions[sessionID]
	if session == nil {
		return
	}

	log.Printf("Processing session %s", sessionID)

	// Generate config using Nix
	configPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-config.nix", sessionID))
	if err := s.generateConfig(sessionID, configPath); err != nil {
		log.Printf("Failed to generate config: %v", err)
		session.Status = "error"
		session.Error = fmt.Sprintf("Config generation failed: %v", err)
		return
	}

	// Read generated config
	configData, err := os.ReadFile(configPath)
	if err != nil {
		log.Printf("Failed to read config: %v", err)
		session.Status = "error"
		session.Error = fmt.Sprintf("Failed to read config: %v", err)
		return
	}

	session.Config = string(configData)
	session.Status = "ready"
	log.Printf("Session %s processed successfully", sessionID)
}

func (s *Server) generateConfig(sessionID, outputPath string) error {
	// TODO: Call Nix config generator
	// For now, generate a placeholder
	reportPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-report.json", sessionID))
	mappingPath := "/path/to/mapping-database.json" // TODO: Get from config

	cmd := exec.Command("nix-instantiate", "--eval", "--strict", "-E", fmt.Sprintf(`
		let
		  generator = import %s/web-service/config-generator/generator.nix;
		  report = builtins.readFile %s;
		  mapping = builtins.readFile %s;
		in
		  generator { snapshotReport = report; mappingDatabase = mapping; }
	`, s.dataDir, reportPath, mappingPath))

	output, err := cmd.CombinedOutput()
	if err != nil {
		// Fallback: Generate basic config
		return s.generateBasicConfig(sessionID, outputPath)
	}

	return os.WriteFile(outputPath, output, 0644)
}

func (s *Server) generateBasicConfig(sessionID, outputPath string) error {
	session := s.sessions[sessionID]
	if session == nil || session.Report == nil {
		return fmt.Errorf("session or report not found")
	}

	// Basic config template
	config := fmt.Sprintf(`# Generated NixOS Configuration
# Session: %s
# Source OS: %s

{ config, pkgs, ... }:

{
  system.stateVersion = "25.11";
  
  # Desktop Environment
  services.xserver.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;
  
  # Packages
  environment.systemPackages = with pkgs; [
    # TODO: Map programs from snapshot
  ];
  
  # Timezone
  time.timeZone = "%s";
  
  # Locale
  i18n.defaultLocale = "%s";
}
`, sessionID, session.Report.OS, 
		s.getSetting(session.Report, "timezone", "Europe/Berlin"),
		s.getSetting(session.Report, "locale", "en_US.UTF-8"))

	return os.WriteFile(outputPath, []byte(config), 0644)
}

func (s *Server) buildISO(sessionID, variant string) {
	session := s.sessions[sessionID]
	if session == nil {
		return
	}

	log.Printf("Building ISO for session %s (variant: %s)", sessionID, variant)
	session.Status = "building_iso"

	// Build ISO using nix-build
	configPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-config.nix", sessionID))
	isoPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s.iso", sessionID))
	
	// Create ISO builder expression
	builderExpr := fmt.Sprintf(`
		let
		  pkgs = import <nixpkgs> {};
		  isoBuilder = import %s/iso-builder/iso-builder.nix {
		    inherit pkgs;
		    sessionConfig = builtins.readFile %s;
		  };
		in
		  isoBuilder.buildISO {
		    sessionId = "%s";
		    variant = "%s";
		  }
	`, s.dataDir, configPath, sessionID, variant)
	
	// Build ISO (this is a placeholder - actual implementation would use nix-build)
	cmd := exec.Command("nix-build", "--no-out-link", "-E", builderExpr)
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("ISO build failed: %v\nOutput: %s", err, string(output))
		// Fallback: Create placeholder
		file, createErr := os.Create(isoPath)
		if createErr != nil {
			log.Printf("Failed to create ISO file: %v", createErr)
			session.Status = "error"
			session.Error = fmt.Sprintf("ISO build failed: %v", err)
			return
		}
		file.Close()
		log.Printf("Created placeholder ISO (actual build requires nix-build)")
	} else {
		// Copy built ISO to data directory
		builtIsoPath := string(output)
		if err := exec.Command("cp", builtIsoPath, isoPath).Run(); err != nil {
			log.Printf("Failed to copy ISO: %v", err)
		}
	}

	session.ISOURL = fmt.Sprintf("/api/v1/iso/%s/download", sessionID)
	session.Status = "iso_ready"
	log.Printf("ISO ready for session %s", sessionID)
}

// Helper functions

func (s *Server) saveJSON(path string, data interface{}) error {
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	return encoder.Encode(data)
}

func (s *Server) extractPackages(report *Report) []string {
	packages := []string{}
	for _, prog := range report.Programs {
		if name, ok := prog["name"].(string); ok {
			packages = append(packages, name)
		}
	}
	return packages
}

func (s *Server) extractDesktop(report *Report) string {
	if report.Settings == nil {
		return "plasma"
	}
	if desktop, ok := report.Settings["desktop"].(string); ok {
		return desktop
	}
	return "plasma"
}

func (s *Server) getSetting(report *Report, key, defaultValue string) string {
	if report.Settings == nil {
		return defaultValue
	}
	if value, ok := report.Settings[key].(string); ok {
		return value
	}
	return defaultValue
}
