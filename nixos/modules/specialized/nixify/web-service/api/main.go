package main

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

//go:embed templates/index.html
var indexTemplate string

//go:embed scripts/nixify-scan.ps1
var windowsScript string

//go:embed scripts/nixify-scan-macos.sh
var macosScript string

//go:embed scripts/nixify-scan-linux.sh
var linuxScript string

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
	sessions      map[string]*Session
	sessionsMutex sync.RWMutex
	port          string
	host          string
	dataDir       string
	template      *template.Template
	
	// Queue system
	queue         chan string // Session IDs to process
	workerCount   int         // Number of concurrent workers
	
	// Rate limiting
	rateLimiter   map[string]time.Time // IP -> last request time
	rateMutex     sync.Mutex
	rateLimit     time.Duration // Minimum time between requests from same IP
	
	// Limits
	maxSessions      int   // Maximum concurrent sessions
	maxRequestSize   int64 // Maximum request body size (10MB)
	maxPrograms      int   // Maximum programs in report
	sessionTTL       time.Duration // Session time-to-live (24h)
	
	// Cleanup
	stopCleanup     chan struct{}
}

func NewServer(port, host, dataDir string) *Server {
	tmpl, err := template.New("index").Parse(indexTemplate)
	if err != nil {
		log.Fatalf("Failed to parse template: %v", err)
	}

	server := &Server{
		sessions:      make(map[string]*Session),
		sessionsMutex: sync.RWMutex{},
		port:          port,
		host:          host,
		dataDir:       dataDir,
		template:      tmpl,
		queue:         make(chan string, 100), // Buffer 100 sessions
		workerCount:   3,                       // 3 concurrent workers
		rateLimiter:   make(map[string]time.Time),
		rateMutex:     sync.Mutex{},
		rateLimit:     5 * time.Second,        // 5 seconds between requests
		maxSessions:   100,                    // Max 100 concurrent sessions
		maxRequestSize: 10 * 1024 * 1024,      // 10MB max request size
		maxPrograms:   10000,                  // Max 10000 programs per report
		sessionTTL:    24 * time.Hour,         // Sessions expire after 24h
		stopCleanup:   make(chan struct{}),
	}

	// Start worker pool
	for i := 0; i < server.workerCount; i++ {
		go server.worker(i)
	}

	// Start cleanup goroutine
	go server.cleanupSessions()

	return server
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
	s.setSecurityHeaders(w)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	
	s.sessionsMutex.RLock()
	sessionCount := len(s.sessions)
	s.sessionsMutex.RUnlock()
	
	data := struct {
		Sessions int
		Host     string
		Port     string
	}{
		Sessions: sessionCount,
		Host:     s.host,
		Port:     s.port,
	}
	
	if err := s.template.Execute(w, data); err != nil {
		log.Printf("Failed to execute template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	s.setSecurityHeaders(w)
	w.Header().Set("Content-Type", "application/json")
	
	s.sessionsMutex.RLock()
	sessionCount := len(s.sessions)
	s.sessionsMutex.RUnlock()
	
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
		"sessions":  sessionCount,
		"queue":     len(s.queue),
	})
}

func (s *Server) handleUpload(w http.ResponseWriter, r *http.Request) {
	// Security: Set security headers
	s.setSecurityHeaders(w)

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Rate limiting
	clientIP := s.getClientIP(r)
	if !s.checkRateLimit(clientIP) {
		http.Error(w, "Rate limit exceeded. Please wait before submitting another request.", http.StatusTooManyRequests)
		return
	}

	// Limit request size
	r.Body = http.MaxBytesReader(w, r.Body, s.maxRequestSize)

	// Validate Content-Type
	contentType := r.Header.Get("Content-Type")
	if !strings.HasPrefix(contentType, "application/json") {
		http.Error(w, "Content-Type must be application/json", http.StatusUnsupportedMediaType)
		return
	}

	// Decode and validate JSON
	var report Report
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields() // Reject unknown fields
	if err := decoder.Decode(&report); err != nil {
		http.Error(w, fmt.Sprintf("Invalid JSON: %v", err), http.StatusBadRequest)
		return
	}

	// Validate report structure
	if err := s.validateReport(&report); err != nil {
		http.Error(w, fmt.Sprintf("Invalid report: %v", err), http.StatusBadRequest)
		return
	}

	// Check session limit
	s.sessionsMutex.RLock()
	sessionCount := len(s.sessions)
	s.sessionsMutex.RUnlock()

	if sessionCount >= s.maxSessions {
		http.Error(w, "Server is at capacity. Please try again later.", http.StatusServiceUnavailable)
		return
	}

	// Create session
	sessionID := uuid.New().String()
	session := &Session{
		ID:        sessionID,
		Status:    "queued",
		CreatedAt: time.Now(),
		Report:    &report,
	}

	// Thread-safe session storage
	s.sessionsMutex.Lock()
	s.sessions[sessionID] = session
	s.sessionsMutex.Unlock()

	// Save report to disk (with path validation)
	reportPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-report.json", sessionID))
	if err := s.saveJSON(reportPath, report); err != nil {
		log.Printf("Failed to save report: %v", err)
		s.sessionsMutex.Lock()
		session.Status = "error"
		session.Error = fmt.Sprintf("Failed to save report: %v", err)
		s.sessionsMutex.Unlock()
		http.Error(w, "Failed to save report", http.StatusInternalServerError)
		return
	}

	// Add to queue (non-blocking)
	select {
	case s.queue <- sessionID:
		s.sessionsMutex.Lock()
		session.Status = "queued"
		s.sessionsMutex.Unlock()
	default:
		// Queue is full
		s.sessionsMutex.Lock()
		session.Status = "error"
		session.Error = "Processing queue is full"
		s.sessionsMutex.Unlock()
		http.Error(w, "Processing queue is full. Please try again later.", http.StatusServiceUnavailable)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"session_id":     sessionID,
		"status":         "queued",
		"estimated_time": "2-5 minutes",
		"queue_position": len(s.queue),
	})
}

func (s *Server) handleListSessions(w http.ResponseWriter, r *http.Request) {
	s.setSecurityHeaders(w)

	s.sessionsMutex.RLock()
	sessions := make([]map[string]interface{}, 0, len(s.sessions))
	for _, session := range s.sessions {
		sessions = append(sessions, map[string]interface{}{
			"id":         session.ID,
			"status":     session.Status,
			"created_at": session.CreatedAt,
			"os":         session.Report.OS,
		})
	}
	s.sessionsMutex.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"sessions": sessions,
	})
}

func (s *Server) handleGetSession(w http.ResponseWriter, r *http.Request) {
	s.setSecurityHeaders(w)

	sessionID := s.sanitizeSessionID(r.URL.Path[len("/api/v1/session/"):])
	if sessionID == "" {
		http.Error(w, "Invalid session ID", http.StatusBadRequest)
		return
	}

	s.sessionsMutex.RLock()
	session, ok := s.sessions[sessionID]
	s.sessionsMutex.RUnlock()

	if !ok {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(session)
}

func (s *Server) handleGetConfig(w http.ResponseWriter, r *http.Request) {
	s.setSecurityHeaders(w)

	sessionID := s.sanitizeSessionID(r.URL.Path[len("/api/v1/config/"):])
	if sessionID == "" {
		http.Error(w, "Invalid session ID", http.StatusBadRequest)
		return
	}

	s.sessionsMutex.RLock()
	session, ok := s.sessions[sessionID]
	s.sessionsMutex.RUnlock()

	if !ok {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	if session.Config == "" {
		http.Error(w, "Configs not yet generated", http.StatusProcessing)
		return
	}

	// Find configs directory
	configsDir := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-configs", sessionID))
	if _, err := os.Stat(configsDir); os.IsNotExist(err) {
		http.Error(w, "Configs directory not found", http.StatusNotFound)
		return
	}

	// Check if client wants JSON (for API) or zip (for download)
	accept := r.Header.Get("Accept")
	if strings.Contains(accept, "application/json") {
		// API response with preview
		configFiles, _ := os.ReadDir(configsDir)
		files := []string{}
		for _, file := range configFiles {
			if !file.IsDir() && file.Name() != "README.md" {
				files = append(files, file.Name())
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"session_id": sessionID,
			"configs_dir": configsDir,
			"files":      files,
			"preview": map[string]interface{}{
				"packages": s.extractPackages(session.Report),
				"modules":  []string{}, // TODO: Extract from config
				"desktop":  s.extractDesktop(session.Report),
			},
		})
	} else {
		// Create zip archive of configs directory
		zipPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-configs.zip", sessionID))
		cmd := exec.Command("zip", "-r", zipPath, configsDir)
		if err := cmd.Run(); err != nil {
			// Fallback: serve directory listing
			w.Header().Set("Content-Type", "text/plain; charset=utf-8")
			fmt.Fprintf(w, "Configs generated in: %s\n\n", configsDir)
			fmt.Fprintf(w, "Files:\n")
			files, _ := os.ReadDir(configsDir)
			for _, file := range files {
				if !file.IsDir() {
					fmt.Fprintf(w, "- %s\n", file.Name())
				}
			}
			return
		}

		// Serve zip file
		w.Header().Set("Content-Type", "application/zip")
		w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=nixos-configs-%s.zip", sessionID))
		http.ServeFile(w, r, zipPath)
	}
}

func (s *Server) handleBuildISO(w http.ResponseWriter, r *http.Request) {
	s.setSecurityHeaders(w)

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Limit request size
	r.Body = http.MaxBytesReader(w, r.Body, 1024*1024) // 1MB max for ISO build request

	var req struct {
		SessionID string `json:"session_id"`
		Variant   string `json:"variant,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid JSON: %v", err), http.StatusBadRequest)
		return
	}

	// Validate and sanitize session ID
	req.SessionID = s.sanitizeSessionID(req.SessionID)
	if req.SessionID == "" {
		http.Error(w, "Invalid session ID", http.StatusBadRequest)
		return
	}

	// Validate variant
	validVariants := map[string]bool{
		"plasma": true,
		"gnome":  true,
		"xfce":   true,
		"kde":    true,
	}
	if req.Variant != "" && !validVariants[strings.ToLower(req.Variant)] {
		http.Error(w, fmt.Sprintf("Invalid variant: %s", req.Variant), http.StatusBadRequest)
		return
	}

	s.sessionsMutex.RLock()
	session, ok := s.sessions[req.SessionID]
	s.sessionsMutex.RUnlock()

	if !ok {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	if session.Config == "" {
		http.Error(w, "Configs not yet generated", http.StatusProcessing)
		return
	}

	// Build ISO in background (via queue would be better, but for now direct)
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
	s.setSecurityHeaders(w)

	path := r.URL.Path[len("/api/v1/iso/"):]
	// Remove "/download" suffix if present
	sessionID := strings.TrimSuffix(path, "/download")
	sessionID = s.sanitizeSessionID(sessionID)
	
	if sessionID == "" {
		http.Error(w, "Invalid session ID", http.StatusBadRequest)
		return
	}

	s.sessionsMutex.RLock()
	session, ok := s.sessions[sessionID]
	s.sessionsMutex.RUnlock()

	if !ok {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	if session.ISOURL == "" {
		http.Error(w, "ISO not yet built", http.StatusProcessing)
		return
	}

	// Serve ISO file (with path validation)
	isoPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s.iso", sessionID))
	
	// Validate path (prevent path traversal)
	cleanPath := filepath.Clean(isoPath)
	if !strings.HasPrefix(cleanPath, s.dataDir) {
		http.Error(w, "Invalid path", http.StatusBadRequest)
		return
	}

	if _, err := os.Stat(cleanPath); os.IsNotExist(err) {
		http.Error(w, "ISO file not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=nixos-nixified-%s.iso", sessionID))
	
	file, err := os.Open(cleanPath)
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
	s.setSecurityHeaders(w)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Content-Disposition", "attachment; filename=nixify-scan.ps1")
	fmt.Fprint(w, windowsScript)
}

func (s *Server) handleDownloadMacOS(w http.ResponseWriter, r *http.Request) {
	s.setSecurityHeaders(w)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Content-Disposition", "attachment; filename=nixify-scan.sh")
	fmt.Fprint(w, macosScript)
}

func (s *Server) handleDownloadLinux(w http.ResponseWriter, r *http.Request) {
	s.setSecurityHeaders(w)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Content-Disposition", "attachment; filename=nixify-scan.sh")
	fmt.Fprint(w, linuxScript)
}

// Worker processes sessions from the queue
func (s *Server) worker(id int) {
	for sessionID := range s.queue {
		log.Printf("[Worker %d] Processing session %s", id, sessionID)
		s.processSession(sessionID)
	}
}

func (s *Server) processSession(sessionID string) {
	// Thread-safe session access
	s.sessionsMutex.RLock()
	session, exists := s.sessions[sessionID]
	s.sessionsMutex.RUnlock()

	if !exists || session == nil {
		log.Printf("Session %s not found", sessionID)
		return
	}

	// Update status
	s.sessionsMutex.Lock()
	session.Status = "processing"
	s.sessionsMutex.Unlock()

	log.Printf("Processing session %s", sessionID)

	// Generate configs using Nix (with path validation)
	configsDir := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-configs", sessionID))
	if err := s.generateConfig(sessionID, configsDir); err != nil {
		log.Printf("Failed to generate config: %v", err)
		s.sessionsMutex.Lock()
		session.Status = "error"
		session.Error = fmt.Sprintf("Config generation failed: %v", err)
		s.sessionsMutex.Unlock()
		return
	}

	// Configs are now in a directory, not a single file
	configsDir := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-configs", sessionID))
	if _, err := os.Stat(configsDir); os.IsNotExist(err) {
		log.Printf("Configs directory not found: %v", err)
		s.sessionsMutex.Lock()
		session.Status = "error"
		session.Error = fmt.Sprintf("Configs directory not found: %v", err)
		s.sessionsMutex.Unlock()
		return
	}

	// List all generated config files
	configFiles, err := os.ReadDir(configsDir)
	if err != nil {
		log.Printf("Failed to read configs directory: %v", err)
		s.sessionsMutex.Lock()
		session.Status = "error"
		session.Error = fmt.Sprintf("Failed to read configs directory: %v", err)
		s.sessionsMutex.Unlock()
		return
	}

	// Build a summary of generated configs
	configSummary := fmt.Sprintf("Generated configs in: %s\n\nFiles:\n", configsDir)
	for _, file := range configFiles {
		if !file.IsDir() && file.Name() != "README.md" {
			configSummary += fmt.Sprintf("- %s\n", file.Name())
		}
	}

	s.sessionsMutex.Lock()
	session.Config = configSummary
	session.Status = "ready"
	s.sessionsMutex.Unlock()

	log.Printf("Session %s processed successfully", sessionID)
}

func (s *Server) generateConfig(sessionID, outputPath string) error {
	// Generate configs/*.nix files using Nix generator
	reportPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-report.json", sessionID))
	mappingPath := os.Getenv("MAPPING_DB_PATH")
	if mappingPath == "" {
		mappingPath = filepath.Join(s.dataDir, "mapping-database.json")
	}

	// Call Nix generator to get configs structure
	cmd := exec.Command("nix-instantiate", "--eval", "--strict", "--json", "-E", fmt.Sprintf(`
		let
		  generator = import %s/web-service/config-generator/generator.nix;
		  report = builtins.readFile %s;
		  mapping = builtins.readFile %s;
		in
		  generator { snapshotReport = report; mappingDatabase = mapping; }
	`, filepath.Join(s.dataDir, ".."), reportPath, mappingPath))

	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Nix generator failed: %v\nOutput: %s", err, string(output))
		// Fallback: Generate basic configs
		return s.generateBasicConfigs(sessionID, outputPath)
	}

	// Parse JSON output from Nix
	var result struct {
		Configs map[string]string `json:"configs"`
	}
	if err := json.Unmarshal(output, &result); err != nil {
		log.Printf("Failed to parse generator output: %v", err)
		return s.generateBasicConfigs(sessionID, outputPath)
	}

	// Create configs directory
	configsDir := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-configs", sessionID))
	if err := os.MkdirAll(configsDir, 0755); err != nil {
		return fmt.Errorf("failed to create configs directory: %v", err)
	}

	// Write each config file
	for fileName, content := range result.Configs {
		configPath := filepath.Join(configsDir, fileName)
		if err := os.WriteFile(configPath, []byte(content), 0644); err != nil {
			log.Printf("Failed to write %s: %v", fileName, err)
			continue
		}
	}

	// Create a summary file listing all generated configs
	summary := fmt.Sprintf("# Generated NixOS Configs\n# Session: %s\n# Generated at: %s\n\n", sessionID, time.Now().Format(time.RFC3339))
	summary += "Generated config files:\n"
	for fileName := range result.Configs {
		summary += fmt.Sprintf("- %s\n", fileName)
	}
	summary += "\nCopy these files to /etc/nixos/configs/ on your NixOS system.\n"

	summaryPath := filepath.Join(configsDir, "README.md")
	if err := os.WriteFile(summaryPath, []byte(summary), 0644); err != nil {
		log.Printf("Failed to write summary: %v", err)
	}

	// Store configs directory path in session (for download)
	s.sessionsMutex.Lock()
	if session, ok := s.sessions[sessionID]; ok {
		session.Config = fmt.Sprintf("Configs generated in: %s", configsDir)
	}
	s.sessionsMutex.Unlock()

	return nil
}

func (s *Server) generateBasicConfigs(sessionID, outputPath string) error {
	s.sessionsMutex.RLock()
	session, exists := s.sessions[sessionID]
	s.sessionsMutex.RUnlock()

	if !exists || session == nil || session.Report == nil {
		return fmt.Errorf("session or report not found")
	}

	// Create configs directory
	configsDir := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-configs", sessionID))
	if err := os.MkdirAll(configsDir, 0755); err != nil {
		return fmt.Errorf("failed to create configs directory: %v", err)
	}

	// Determine desktop environment
	desktopEnv := "plasma"
	if session.Report.OS == "macos" {
		desktopEnv = "gnome"
	} else if session.Report.OS == "linux" {
		if desktop, ok := session.Report.Settings["desktop"].(string); ok {
			if desktop == "GNOME" || desktop == "gnome" {
				desktopEnv = "gnome"
			} else if desktop == "KDE" || desktop == "kde" {
				desktopEnv = "plasma"
			}
		}
	}

	// Generate desktop-config.nix
	desktopConfig := fmt.Sprintf(`{
  # Desktop-Environment
  desktop = {
    enable = true;
    environment = "%s";
  };
}
`, desktopEnv)
	if err := os.WriteFile(filepath.Join(configsDir, "desktop-config.nix"), []byte(desktopConfig), 0644); err != nil {
		return fmt.Errorf("failed to write desktop-config.nix: %v", err)
	}

	// Generate packages-config.nix
	packagesConfig := `{
  # Packages from snapshot
  packages = {
    systemPackages = [
      # TODO: Map programs from snapshot to NixOS packages
    ];
  };
}
`
	if err := os.WriteFile(filepath.Join(configsDir, "packages-config.nix"), []byte(packagesConfig), 0644); err != nil {
		return fmt.Errorf("failed to write packages-config.nix: %v", err)
	}

	// Generate localization-config.nix
	timezone := s.getSetting(session.Report, "timezone", "Europe/Berlin")
	locale := s.getSetting(session.Report, "locale", "en_US.UTF-8")
	localizationConfig := fmt.Sprintf(`{
  # System Settings
  localization = {
    timeZone = "%s";
    locale = "%s";
  };
}
`, timezone, locale)
	if err := os.WriteFile(filepath.Join(configsDir, "localization-config.nix"), []byte(localizationConfig), 0644); err != nil {
		return fmt.Errorf("failed to write localization-config.nix: %v", err)
	}

	// Create README
	summary := fmt.Sprintf(`# Generated NixOS Configs
# Session: %s
# Source OS: %s
# Generated at: %s

Generated config files:
- desktop-config.nix
- packages-config.nix
- localization-config.nix

Copy these files to /etc/nixos/configs/ on your NixOS system.
`, sessionID, session.Report.OS, time.Now().Format(time.RFC3339))
	if err := os.WriteFile(filepath.Join(configsDir, "README.md"), []byte(summary), 0644); err != nil {
		log.Printf("Failed to write README: %v", err)
	}

	// Store configs directory path in session
	s.sessionsMutex.Lock()
	session.Config = fmt.Sprintf("Configs generated in: %s", configsDir)
	s.sessionsMutex.Unlock()

	return nil
}

func (s *Server) buildISO(sessionID, variant string) {
	s.sessionsMutex.RLock()
	session, exists := s.sessions[sessionID]
	s.sessionsMutex.RUnlock()

	if !exists || session == nil {
		log.Printf("Session %s not found for ISO build", sessionID)
		return
	}

	log.Printf("Building ISO for session %s (variant: %s)", sessionID, variant)
	
	s.sessionsMutex.Lock()
	session.Status = "building_iso"
	s.sessionsMutex.Unlock()

	// Build ISO using nix-build
	configsDir := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-configs", sessionID))
	isoPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s.iso", sessionID))
	
	// Read all config files from configs directory
	configFiles, err := os.ReadDir(configsDir)
	if err != nil {
		log.Printf("Failed to read configs directory: %v", err)
		s.sessionsMutex.Lock()
		session.Status = "error"
		session.Error = fmt.Sprintf("Failed to read configs directory: %v", err)
		s.sessionsMutex.Unlock()
		return
	}

	// Build configs map for Nix
	configsMap := "{ "
	for _, file := range configFiles {
		if !file.IsDir() && file.Name() != "README.md" {
			content, _ := os.ReadFile(filepath.Join(configsDir, file.Name()))
			// Escape for Nix string
			escaped := strings.ReplaceAll(string(content), "\"", "\\\"")
			escaped = strings.ReplaceAll(escaped, "\n", "\\n")
			configsMap += fmt.Sprintf("\"%s\" = \"%s\"; ", file.Name(), escaped)
		}
	}
	configsMap += "}"

	// Create ISO builder expression
	builderExpr := fmt.Sprintf(`
		let
		  pkgs = import <nixpkgs> {};
		  isoBuilder = import %s/iso-builder/iso-builder.nix {
		    inherit pkgs;
		    sessionConfigs = %s;
		  };
		in
		  isoBuilder.buildISO {
		    sessionId = "%s";
		    variant = "%s";
		  }
	`, filepath.Join(s.dataDir, ".."), configsMap, sessionID, variant)
	
	// Build ISO (this is a placeholder - actual implementation would use nix-build)
	cmd := exec.Command("nix-build", "--no-out-link", "-E", builderExpr)
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("ISO build failed: %v\nOutput: %s", err, string(output))
		// Fallback: Create placeholder
		file, createErr := os.Create(isoPath)
		if createErr != nil {
			log.Printf("Failed to create ISO file: %v", createErr)
			s.sessionsMutex.Lock()
			session.Status = "error"
			session.Error = fmt.Sprintf("ISO build failed: %v", err)
			s.sessionsMutex.Unlock()
			return
		}
		file.Close()
		log.Printf("Created placeholder ISO (actual build requires nix-build)")
	} else {
		// Copy built ISO to data directory
		builtIsoPath := strings.TrimSpace(string(output))
		if err := exec.Command("cp", builtIsoPath, isoPath).Run(); err != nil {
			log.Printf("Failed to copy ISO: %v", err)
		}
	}

	s.sessionsMutex.Lock()
	session.ISOURL = fmt.Sprintf("/api/v1/iso/%s/download", sessionID)
	session.Status = "iso_ready"
	s.sessionsMutex.Unlock()
	
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

// Security and validation helpers

func (s *Server) setSecurityHeaders(w http.ResponseWriter) {
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("X-Frame-Options", "DENY")
	w.Header().Set("X-XSS-Protection", "1; mode=block")
	w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
	w.Header().Set("Content-Security-Policy", "default-src 'self'")
}

func (s *Server) getClientIP(r *http.Request) string {
	// Check X-Forwarded-For header (for reverse proxies)
	forwarded := r.Header.Get("X-Forwarded-For")
	if forwarded != "" {
		ips := strings.Split(forwarded, ",")
		if len(ips) > 0 {
			return strings.TrimSpace(ips[0])
		}
	}

	// Check X-Real-IP header
	realIP := r.Header.Get("X-Real-IP")
	if realIP != "" {
		return realIP
	}

	// Fallback to RemoteAddr
	ip := r.RemoteAddr
	if idx := strings.LastIndex(ip, ":"); idx != -1 {
		ip = ip[:idx]
	}
	return ip
}

func (s *Server) checkRateLimit(clientIP string) bool {
	s.rateMutex.Lock()
	defer s.rateMutex.Unlock()

	lastRequest, exists := s.rateLimiter[clientIP]
	if !exists || time.Since(lastRequest) > s.rateLimit {
		s.rateLimiter[clientIP] = time.Now()
		return true
	}

	return false
}

func (s *Server) validateReport(report *Report) error {
	// Validate OS
	validOS := map[string]bool{
		"windows": true,
		"macos":   true,
		"linux":   true,
	}
	if !validOS[strings.ToLower(report.OS)] {
		return fmt.Errorf("invalid OS: %s", report.OS)
	}

	// Validate programs count
	if len(report.Programs) > s.maxPrograms {
		return fmt.Errorf("too many programs: %d (max: %d)", len(report.Programs), s.maxPrograms)
	}

	// Validate program names (prevent injection)
	for i, prog := range report.Programs {
		if name, ok := prog["name"].(string); ok {
			// Check for path traversal attempts
			if strings.Contains(name, "..") || strings.Contains(name, "/") || strings.Contains(name, "\\") {
				return fmt.Errorf("invalid program name at index %d: contains path characters", i)
			}
			// Limit name length
			if len(name) > 500 {
				return fmt.Errorf("program name too long at index %d: %d characters (max: 500)", i, len(name))
			}
		}
	}

	// Validate timestamp format (basic check)
	if report.Timestamp != "" {
		if _, err := time.Parse(time.RFC3339, report.Timestamp); err != nil {
			// Not critical, but log it
			log.Printf("Warning: Invalid timestamp format: %s", report.Timestamp)
		}
	}

	return nil
}

func (s *Server) sanitizeSessionID(sessionID string) string {
	// Remove any path traversal or special characters
	sessionID = strings.TrimSpace(sessionID)
	sessionID = strings.ReplaceAll(sessionID, "/", "")
	sessionID = strings.ReplaceAll(sessionID, "\\", "")
	sessionID = strings.ReplaceAll(sessionID, "..", "")
	
	// Validate UUID format (basic check)
	if len(sessionID) != 36 {
		return ""
	}
	
	return sessionID
}

// cleanupSessions periodically removes old sessions
func (s *Server) cleanupSessions() {
	ticker := time.NewTicker(1 * time.Hour) // Run every hour
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			s.sessionsMutex.Lock()
			now := time.Now()
			removed := 0
			for id, session := range s.sessions {
				if now.Sub(session.CreatedAt) > s.sessionTTL {
					// Remove old session files
					reportPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-report.json", id))
					configsDir := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-configs", id))
					isoPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s.iso", id))
					
					os.Remove(reportPath)
					os.RemoveAll(configsDir) // Remove entire configs directory
					os.Remove(isoPath)
					
					delete(s.sessions, id)
					removed++
				}
			}
			s.sessionsMutex.Unlock()
			
			if removed > 0 {
				log.Printf("Cleaned up %d expired sessions", removed)
			}
			
			// Cleanup rate limiter (remove entries older than 1 hour)
			s.rateMutex.Lock()
			for ip, lastRequest := range s.rateLimiter {
				if time.Since(lastRequest) > time.Hour {
					delete(s.rateLimiter, ip)
				}
			}
			s.rateMutex.Unlock()
			
		case <-s.stopCleanup:
			return
		}
	}
}
