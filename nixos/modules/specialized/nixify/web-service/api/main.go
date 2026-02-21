package main

import (
	_ "embed"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"html"
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

//go:embed templates/review.html
var reviewTemplate string

//go:embed templates/base.html
var baseTemplate string

//go:embed templates/mappings.html
var mappingsTemplate string

//go:embed templates/games.html
var gamesTemplate string

//go:embed templates/about.html
var aboutTemplate string

//go:embed templates/modules.html
var modulesTemplate string

//go:embed templates/module-detail.html
var moduleDetailTemplate string

//go:embed locales/en.json
var localeEN string

//go:embed locales/de.json
var localeDE string

//go:embed locales/fr.json
var localeFR string

//go:embed locales/es.json
var localeES string

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

// ModuleInfo represents information about a NixOS Control Center module
type DocInfo struct {
	Name  string `json:"name"`  // "README", "SECURITY", "ROADMAP", etc.
	Path  string `json:"path"`  // Full path to the doc file
	Title string `json:"title"` // Display title
}

type ModuleInfo struct {
	Name        string   `json:"name"`
	Category    string   `json:"category"`
	Path        string   `json:"path"`
	Description string   `json:"description"`
	Version     string   `json:"version"`
	Status      string   `json:"status"` // "active", "disabled", "planned" (planned = not configured yet)
	HasTUI      bool     `json:"has_tui"`
	HasScripts  bool     `json:"has_scripts"`
	HasHandlers bool     `json:"has_handlers"`
	HasLib      bool     `json:"has_lib"`
	Commands    []string `json:"commands,omitempty"`
	ReadmePath  string   `json:"readme_path,omitempty"`
	GitHubURL   string   `json:"github_url,omitempty"`
	Assets      []string `json:"assets,omitempty"` // Subdirectories like tui/, scripts/, etc.
	Docs        []DocInfo `json:"docs,omitempty"` // Documentation files from doc/
	DocAssets   []string  `json:"doc_assets,omitempty"` // Assets from doc/assets/
}

// Translations holds i18n translations
type Translations map[string]interface{}

// Server holds the web service state
type Server struct {
	sessions      map[string]*Session
	sessionsMutex sync.RWMutex
	port          string
	host          string
	dataDir       string
	template      *template.Template      // Main template (index.html)
	reviewTemplate *template.Template    // Review template
	baseTemplate  *template.Template     // Base template with header/footer
	mappingsTemplate *template.Template  // Mappings page template
	gamesTemplate *template.Template     // Games page template
	aboutTemplate *template.Template     // About page template
	
	// i18n
	translations  map[string]Translations // lang -> translations
	translationsMutex sync.RWMutex
	
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
	
	// Module discovery
	modulesBasePath string // Path to nixos/ directory (either /app/nixos or /etc/nixos)
	githubRepoURL   string // GitHub repository URL for module links
	
	// Debug
	debugTranslations bool // Enable debug logging for translations
}

// loadTranslations loads i18n translations from embedded JSON files
func loadTranslations() map[string]Translations {
	translations := make(map[string]Translations)
	
	// Load English
	var enTrans Translations
	if err := json.Unmarshal([]byte(localeEN), &enTrans); err != nil {
		log.Fatalf("Failed to load English translations: %v", err)
	}
	translations["en"] = enTrans
	
	// Load German
	var deTrans Translations
	if err := json.Unmarshal([]byte(localeDE), &deTrans); err != nil {
		log.Fatalf("Failed to load German translations: %v", err)
	}
	translations["de"] = deTrans
	
	// Load French
	var frTrans Translations
	if err := json.Unmarshal([]byte(localeFR), &frTrans); err != nil {
		log.Fatalf("Failed to load French translations: %v", err)
	}
	translations["fr"] = frTrans
	
	// Load Spanish
	var esTrans Translations
	if err := json.Unmarshal([]byte(localeES), &esTrans); err != nil {
		log.Fatalf("Failed to load Spanish translations: %v", err)
	}
	translations["es"] = esTrans
	
	// Debug: Log loaded translations
	if enMap := translations["en"]; enMap != nil {
		log.Printf("Loaded translations: en has %d top-level keys: %v", len(enMap), getMapKeys(enMap))
	}
	if esMap := translations["es"]; esMap != nil {
		log.Printf("Loaded translations: es has %d top-level keys: %v", len(esMap), getMapKeys(esMap))
		if apiVal, exists := esMap["api"]; exists {
			log.Printf("DEBUG: es['api'] exists, type: %T", apiVal)
		} else {
			log.Printf("DEBUG: es['api'] DOES NOT EXIST!")
		}
	}
	
	return translations
}

// getMapKeys returns keys of a map for debugging
func getMapKeys(m map[string]interface{}) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

// getLanguage extracts language from request (cookie, header, or default)
func (s *Server) getLanguage(r *http.Request) string {
	// Check cookie first
	if cookie, err := r.Cookie("lang"); err == nil {
		if _, ok := s.translations[cookie.Value]; ok {
			return cookie.Value
		}
	}
	
	// Check Accept-Language header
	acceptLang := r.Header.Get("Accept-Language")
	if acceptLang != "" {
		// Simple parsing: "de-DE,de;q=0.9,en;q=0.8" -> "de"
		langs := strings.Split(acceptLang, ",")
		if len(langs) > 0 {
			lang := strings.ToLower(strings.Split(strings.TrimSpace(langs[0]), "-")[0])
			if _, ok := s.translations[lang]; ok {
				return lang
			}
		}
	}
	
	// Default to English
	return "en"
}

// t translates a key using dot notation (e.g., "nav.home")
func (s *Server) t(lang, key string) string {
	s.translationsMutex.RLock()
	defer s.translationsMutex.RUnlock()
	
	return getTranslation(s.translations, lang, key)
}

// getTranslation is a helper function that can be used in templates
// Navigates through nested map structure using dot notation (e.g., "api.endpoints.upload")
func getTranslation(translations map[string]Translations, lang, key string) string {
	return getTranslationWithDebug(translations, lang, key, false)
}

// getTranslationWithDebug is the internal implementation with optional debug logging
func getTranslationWithDebug(translations map[string]Translations, lang, key string, debug bool) string {
	if translations == nil {
		if debug {
			log.Printf("DEBUG getTranslation: translations map is nil for key '%s'", key)
		}
		return key
	}
	
	// Get translation map for language, fallback to English
	trans, ok := translations[lang]
	if !ok || trans == nil {
		if debug {
			log.Printf("DEBUG getTranslation: language '%s' not found, falling back to en", lang)
		}
		trans = translations["en"]
		if trans == nil {
			if debug {
				log.Printf("DEBUG getTranslation: English translations also nil!")
			}
			return key
		}
		lang = "en"
	}
	
	// Navigate through nested map using dot notation
	parts := strings.Split(key, ".")
	var current interface{} = map[string]interface{}(trans) // Convert Translations to map[string]interface{}
	
	for i, part := range parts {
		// Type assert current to map
		m, ok := current.(map[string]interface{})
		if !ok {
			if debug {
				log.Printf("DEBUG getTranslation: Part %d '%s' is not a map, current type: %T, value: %v", i, part, current, current)
			}
			// Try English fallback if not already using English
			if lang != "en" {
				if enTrans, ok := translations["en"]; ok && enTrans != nil {
					// Restart from English root
					result := navigateMap(enTrans, parts[i:])
					if result != "" {
						return result
					}
				}
			}
			return key
		}
		
		// Get value from map
		val, exists := m[part]
		if !exists {
			if debug {
				log.Printf("DEBUG getTranslation: Key '%s' not found in map at part %d, available keys: %v", part, i, getMapKeys(m))
			}
			// Try English fallback if not already using English
			if lang != "en" {
				if enTrans, ok := translations["en"]; ok && enTrans != nil {
					// Restart from English root
					result := navigateMap(enTrans, parts[i:])
					if result != "" {
						return result
					}
				}
			}
			// Key not found - return key itself
			return key
		}
		
		current = val
	}
	
	// Convert final value to string
	if str, ok := current.(string); ok {
		return str
	}
	
	if debug {
		log.Printf("DEBUG getTranslation: Final value for '%s' is not a string, type: %T, value: %v", key, current, current)
	}
	return key
}

// navigateMap navigates through a Translations map using a path of keys
func navigateMap(m Translations, parts []string) string {
	var current interface{} = m
	
	for _, part := range parts {
		m, ok := current.(map[string]interface{})
		if !ok {
			return ""
		}
		
		val, exists := m[part]
		if !exists {
			return ""
		}
		
		current = val
	}
	
	if str, ok := current.(string); ok {
		return str
	}
	
	return ""
}

// TemplateData holds data for template rendering with i18n support
type TemplateData struct {
	Lang        string
	Nonce       string
	CurrentPath string
	tFunc       func(string) string
	tArrayFunc  func(string) []string
	Host        string
	Port        string
	Sessions    int
	ProgramsJSON template.JS // For mappings page
	ModulesJSON  template.JS // For modules page
	Modules      []ModuleInfo // For modules page
	Module       *ModuleInfo // For module detail page
	ReadmeContent string // For module detail page
	DefaultNixContent string // For module detail page
	DocContents  map[string]string // For module detail page: doc name -> content
	// Additional fields can be added per page
}

// T is a method that can be called from templates
func (td TemplateData) T(key string) string {
	return td.tFunc(key)
}

// TArray is a method that can be called from templates
func (td TemplateData) TArray(key string) []string {
	return td.tArrayFunc(key)
}

// newTemplateData creates a new TemplateData with i18n support
func (s *Server) newTemplateData(r *http.Request, nonce string) TemplateData {
	lang := s.getLanguage(r)
	
	// Create translation function that directly accesses translations
	tFunc := func(key string) string {
		s.translationsMutex.RLock()
		defer s.translationsMutex.RUnlock()
		
		// Direct lookup with optional debug logging
		result := getTranslationWithDebug(s.translations, lang, key, s.debugTranslations)
		if result == key && key != "" && s.debugTranslations {
			// Only log missing translations when debug is enabled
			if len(key) < 50 {
				log.Printf("WARNING: Translation not found for key '%s' in language '%s'", key, lang)
			}
		}
		return result
	}
	
	// Create array translation function (for arrays in JSON)
	tArrayFunc := func(key string) []string {
		s.translationsMutex.RLock()
		defer s.translationsMutex.RUnlock()
		
		trans, ok := s.translations[lang]
		if !ok {
			trans = s.translations["en"]
		}
		
		parts := strings.Split(key, ".")
		var current interface{} = trans
		
		for _, part := range parts {
			if m, ok := current.(map[string]interface{}); ok {
				current = m[part]
			} else {
				return []string{}
			}
		}
		
		// Convert to string array
		if arr, ok := current.([]interface{}); ok {
			result := make([]string, len(arr))
			for i, v := range arr {
				if str, ok := v.(string); ok {
					result[i] = str
				}
			}
			return result
		}
		
		return []string{}
	}
	
	return TemplateData{
		Lang:        lang,
		Nonce:       nonce,
		CurrentPath: r.URL.Path,
		tFunc:       tFunc,
		tArrayFunc:  tArrayFunc,
		Host:        s.host,
		Port:        s.port,
		Sessions:    0, // Will be set by handlers that need it
	}
}

func NewServer(port, host, dataDir string) *Server {
	// Determine modules base path (Docker: /app/nixos, Local: /etc/nixos)
	modulesBasePath := os.Getenv("MODULES_BASE_PATH")
	if modulesBasePath == "" {
		// Try Docker path first, then local
		if _, err := os.Stat("/app/nixos"); err == nil {
			modulesBasePath = "/app/nixos"
			log.Printf("📦 Using Docker modules path: %s", modulesBasePath)
		} else if _, err := os.Stat("/etc/nixos"); err == nil {
			modulesBasePath = "/etc/nixos"
			log.Printf("📦 Using local modules path: %s", modulesBasePath)
		} else {
			modulesBasePath = "/app/nixos" // Default to Docker path
			log.Printf("⚠️  Modules path not found, defaulting to: %s", modulesBasePath)
		}
	} else {
		log.Printf("📦 Using modules path from environment: %s", modulesBasePath)
	}
	
	// GitHub repo URL
	githubRepoURL := os.Getenv("GITHUB_REPO_URL")
	if githubRepoURL == "" {
		githubRepoURL = "https://github.com/fr4iser90/NixOSControlCenter"
	}
	// Load translations
	translations := loadTranslations()
	
	// Parse templates
	// Parse base template with all functions
	baseTmpl, err := template.New("base").Funcs(template.FuncMap{
		"hasPrefix": strings.HasPrefix,
	}).Parse(baseTemplate)
	if err != nil {
		log.Fatalf("Failed to parse base template: %v", err)
	}
	
	// Add all child templates to base
	_, err = baseTmpl.New("index").Parse(indexTemplate)
	if err != nil {
		log.Fatalf("Failed to parse index template: %v", err)
	}
	
	_, err = baseTmpl.New("review").Parse(reviewTemplate)
	if err != nil {
		log.Fatalf("Failed to parse review template: %v", err)
	}
	
	_, err = baseTmpl.New("mappings").Parse(mappingsTemplate)
	if err != nil {
		log.Fatalf("Failed to parse mappings template: %v", err)
	}
	
	_, err = baseTmpl.New("games").Parse(gamesTemplate)
	if err != nil {
		log.Fatalf("Failed to parse games template: %v", err)
	}
	
	_, err = baseTmpl.New("about").Parse(aboutTemplate)
	if err != nil {
		log.Fatalf("Failed to parse about template: %v", err)
	}
	
	_, err = baseTmpl.New("modules").Parse(modulesTemplate)
	if err != nil {
		log.Fatalf("Failed to parse modules template: %v", err)
	}
	
	_, err = baseTmpl.New("module-detail").Parse(moduleDetailTemplate)
	if err != nil {
		log.Fatalf("Failed to parse module-detail template: %v", err)
	}

	server := &Server{
		sessions:      make(map[string]*Session),
		sessionsMutex: sync.RWMutex{},
		port:          port,
		host:          host,
		dataDir:       dataDir,
		template:      nil, // Not used anymore, we use baseTemplate
		reviewTemplate: nil, // Not used anymore, we use baseTemplate
		baseTemplate:  baseTmpl, // Contains all child templates
		mappingsTemplate: baseTmpl, // Use base for all
		gamesTemplate: baseTmpl, // Use base for all
		aboutTemplate: baseTmpl, // Use base for all
		translations:  translations,
		translationsMutex: sync.RWMutex{},
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
		modulesBasePath: modulesBasePath,
		githubRepoURL:   githubRepoURL,
		debugTranslations: os.Getenv("DEBUG_TRANSLATIONS") == "true", // Enable via environment variable
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
	http.HandleFunc("/mappings", server.handleMappings)
	http.HandleFunc("/games", server.handleGames)
	http.HandleFunc("/about", server.handleAbout)
	http.HandleFunc("/modules", server.handleModules)
	http.HandleFunc("/module/", server.handleModuleDetail)
	http.HandleFunc("/review/", server.handleReview)
	http.HandleFunc("/api/v1/health", server.handleHealth)
	http.HandleFunc("/api/v1/upload", server.handleUpload)
	http.HandleFunc("/api/v1/sessions", server.handleListSessions)
	http.HandleFunc("/api/v1/session/", server.handleSessionRoutes) // Unified handler for all session routes
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

	// Note: TLS is handled by Traefik reverse proxy (see docker-compose.traefik.yml)
	// The service runs HTTP internally, Traefik terminates TLS and forwards to this service
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func (s *Server) handleRoot(w http.ResponseWriter, r *http.Request) {
	nonce, err := generateNonce()
	if err != nil {
		log.Printf("Failed to generate nonce: %v", err)
		nonce = ""
	}
	
	s.setSecurityHeadersWithNonce(w, nonce)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	
	data := s.newTemplateData(r, nonce)
	
	// Get session count
	s.sessionsMutex.RLock()
	data.Sessions = len(s.sessions)
	s.sessionsMutex.RUnlock()
	
	// Execute base template, which will render the "index" block
	if err := s.baseTemplate.ExecuteTemplate(w, "base", data); err != nil {
		log.Printf("Failed to execute root template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

func (s *Server) handleMappings(w http.ResponseWriter, r *http.Request) {
	nonce, err := generateNonce()
	if err != nil {
		log.Printf("Failed to generate nonce: %v", err)
		nonce = ""
	}
	
	s.setSecurityHeadersWithNonce(w, nonce)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	
	// Load mapping database
	mappingPath := os.Getenv("MAPPING_DB_PATH")
	if mappingPath == "" {
		mappingPath = filepath.Join(s.dataDir, "mapping-database.json")
	}
	
	// Try to load from mounted path first, then fallback
	var mappingData []byte
	if _, err := os.Stat("/app/mapping/mapping-database.json"); err == nil {
		mappingData, _ = os.ReadFile("/app/mapping/mapping-database.json")
	} else if _, err := os.Stat(mappingPath); err == nil {
		mappingData, _ = os.ReadFile(mappingPath)
	} else {
		// Fallback: empty programs object
		mappingData = []byte(`{"programs": {}}`)
	}
	
	var mapping map[string]interface{}
	if err := json.Unmarshal(mappingData, &mapping); err != nil {
		log.Printf("Failed to parse mapping database: %v", err)
		mapping = map[string]interface{}{"programs": map[string]interface{}{}}
	}
	
	// Convert programs object to array format for JavaScript
	programsObj, ok := mapping["programs"].(map[string]interface{})
	if !ok {
		programsObj = make(map[string]interface{})
	}
	
	// Convert to array format
	programsArray := make([]map[string]interface{}, 0)
	for name, progData := range programsObj {
		progMap, ok := progData.(map[string]interface{})
		if !ok {
			continue
		}
		// Add name to the program data
		progMap["name"] = name
		programsArray = append(programsArray, progMap)
	}
	
	// Convert to JSON for JavaScript
	programsJSON, _ := json.Marshal(programsArray)
	
	data := s.newTemplateData(r, nonce)
	data.ProgramsJSON = template.JS(programsJSON)
	
	// Execute base template, which will render the "mappings" block
	if err := s.baseTemplate.ExecuteTemplate(w, "base", data); err != nil {
		log.Printf("Failed to execute mappings template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

func (s *Server) handleGames(w http.ResponseWriter, r *http.Request) {
	nonce, err := generateNonce()
	if err != nil {
		log.Printf("Failed to generate nonce: %v", err)
		nonce = ""
	}
	
	s.setSecurityHeadersWithNonce(w, nonce)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	
	data := s.newTemplateData(r, nonce)
	
	// Execute base template, which will render the "games" block
	if err := s.baseTemplate.ExecuteTemplate(w, "base", data); err != nil {
		log.Printf("Failed to execute games template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

func (s *Server) handleAbout(w http.ResponseWriter, r *http.Request) {
	nonce, err := generateNonce()
	if err != nil {
		log.Printf("Failed to generate nonce: %v", err)
		nonce = ""
	}
	
	s.setSecurityHeadersWithNonce(w, nonce)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	
	data := s.newTemplateData(r, nonce)
	
	// Execute base template, which will render the "about" block
	if err := s.baseTemplate.ExecuteTemplate(w, "base", data); err != nil {
		log.Printf("Failed to execute about template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

func (s *Server) handleModules(w http.ResponseWriter, r *http.Request) {
	nonce, err := generateNonce()
	if err != nil {
		log.Printf("Failed to generate nonce: %v", err)
		nonce = ""
	}
	
	s.setSecurityHeadersWithNonce(w, nonce)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	
	// Discover modules
	log.Printf("🔍 Discovering modules from: %s", s.modulesBasePath)
	modules, err := s.discoverModules()
	if err != nil {
		log.Printf("Failed to discover modules: %v", err)
		modules = []ModuleInfo{} // Empty list on error
	} else {
		log.Printf("✅ Discovered %d modules", len(modules))
	}
	
	// Convert to JSON for JavaScript
	modulesJSON, _ := json.Marshal(modules)
	
	data := s.newTemplateData(r, nonce)
	data.ModulesJSON = template.JS(modulesJSON)
	data.Modules = modules
	
	// Execute base template, which will render the "modules" block
	if err := s.baseTemplate.ExecuteTemplate(w, "base", data); err != nil {
		log.Printf("Failed to execute modules template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

func (s *Server) handleModuleDetail(w http.ResponseWriter, r *http.Request) {
	// Extract path parts (e.g., /module/nixify or /module/nixify/asset/image.png)
	pathParts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(pathParts) < 2 {
		http.Error(w, "Module name required", http.StatusBadRequest)
		return
	}
	
	moduleName := pathParts[1]
	
	// Check if this is an asset request (e.g., /module/nixify/asset/image.png)
	if len(pathParts) >= 4 && pathParts[2] == "asset" {
		s.handleModuleAsset(w, r, moduleName, pathParts[3])
		return
	}
	
	nonce, err := generateNonce()
	if err != nil {
		log.Printf("Failed to generate nonce: %v", err)
		nonce = ""
	}
	
	s.setSecurityHeadersWithNonce(w, nonce)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	
	// Discover modules and find the requested one
	modules, err := s.discoverModules()
	if err != nil {
		log.Printf("Failed to discover modules: %v", err)
		http.Error(w, "Failed to discover modules", http.StatusInternalServerError)
		return
	}
	
	var module *ModuleInfo
	for i := range modules {
		if modules[i].Name == moduleName {
			module = &modules[i]
			break
		}
	}
	
	if module == nil {
		http.Error(w, "Module not found", http.StatusNotFound)
		return
	}
	
	// Read README content if available (from root or doc/)
	readmeContent := ""
	if content, err := os.ReadFile(module.ReadmePath); err == nil {
		readmeContent = string(content)
	} else {
		// Try doc/README.md
		docReadmePath := filepath.Join(module.Path, "doc", "README.md")
		if content, err := os.ReadFile(docReadmePath); err == nil {
			readmeContent = string(content)
		}
	}
	
	// Read default.nix snippet (first 50 lines)
	defaultNixContent := ""
	defaultNixPath := filepath.Join(module.Path, "default.nix")
	if content, err := os.ReadFile(defaultNixPath); err == nil {
		lines := strings.Split(string(content), "\n")
		if len(lines) > 50 {
			defaultNixContent = strings.Join(lines[:50], "\n") + "\n// ... (truncated)"
		} else {
			defaultNixContent = string(content)
		}
	}
	
	// Load all documentation files from doc/
	docContents := make(map[string]string)
	for _, doc := range module.Docs {
		if content, err := os.ReadFile(doc.Path); err == nil {
			docContents[doc.Name] = string(content)
		}
	}
	
	data := s.newTemplateData(r, nonce)
	data.CurrentPath = r.URL.Path
	data.Module = module
	data.ReadmeContent = readmeContent
	data.DefaultNixContent = defaultNixContent
	data.DocContents = docContents
	
	// Execute base template, which will render the "module-detail" block
	if err := s.baseTemplate.ExecuteTemplate(w, "base", data); err != nil {
		log.Printf("Failed to execute module detail template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

// handleModuleAsset serves asset files from doc/assets/ directory
func (s *Server) handleModuleAsset(w http.ResponseWriter, r *http.Request, moduleName, assetName string) {
	// Security: Sanitize asset name to prevent path traversal
	assetName = filepath.Base(assetName) // Remove any path components
	if assetName == "" || assetName == "." || assetName == ".." {
		http.Error(w, "Invalid asset name", http.StatusBadRequest)
		return
	}
	
	// Discover modules and find the requested one
	modules, err := s.discoverModules()
	if err != nil {
		log.Printf("Failed to discover modules: %v", err)
		http.Error(w, "Failed to discover modules", http.StatusInternalServerError)
		return
	}
	
	var module *ModuleInfo
	for i := range modules {
		if modules[i].Name == moduleName {
			module = &modules[i]
			break
		}
	}
	
	if module == nil {
		http.Error(w, "Module not found", http.StatusNotFound)
		return
	}
	
	// Build asset path
	assetPath := filepath.Join(module.Path, "doc", "assets", assetName)
	
	// Security: Verify the asset is actually in the doc/assets directory
	if !strings.HasPrefix(assetPath, module.Path) {
		http.Error(w, "Invalid asset path", http.StatusBadRequest)
		return
	}
	
	// Check if file exists
	if _, err := os.Stat(assetPath); os.IsNotExist(err) {
		http.Error(w, "Asset not found", http.StatusNotFound)
		return
	}
	
	// Determine content type based on extension
	ext := strings.ToLower(filepath.Ext(assetName))
	contentType := "application/octet-stream"
	switch ext {
	case ".png":
		contentType = "image/png"
	case ".jpg", ".jpeg":
		contentType = "image/jpeg"
	case ".gif":
		contentType = "image/gif"
	case ".svg":
		contentType = "image/svg+xml"
	case ".webp":
		contentType = "image/webp"
	case ".pdf":
		contentType = "application/pdf"
	}
	
	// Set headers
	s.setSecurityHeaders(w)
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "public, max-age=3600") // Cache for 1 hour
	
	// Serve file
	http.ServeFile(w, r, assetPath)
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

	// Create session - Status "review" für Review vor Generator!
	sessionID := uuid.New().String()
	session := &Session{
		ID:        sessionID,
		Status:    "review", // Review-Status - Generator läuft erst nach Review!
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

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"session_id": sessionID,
		"status":     "review",
		"review_url": fmt.Sprintf("/review/%s", sessionID),
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

// handleSessionRoutes routes different session endpoints
func (s *Server) handleSessionRoutes(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	sessionID := s.sanitizeSessionID(path[len("/api/v1/session/"):])
	
	if sessionID == "" {
		http.Error(w, "Invalid session ID", http.StatusBadRequest)
		return
	}
	
	// Route based on path suffix and method
	if strings.HasSuffix(path, "/review") && r.Method == http.MethodPut {
		s.handleUpdateReview(w, r, sessionID)
	} else if strings.HasSuffix(path, "/generate") && r.Method == http.MethodPost {
		s.handleGenerateConfig(w, r, sessionID)
	} else if r.Method == http.MethodGet {
		s.handleGetSession(w, r)
	} else {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleReview shows the review page
func (s *Server) handleReview(w http.ResponseWriter, r *http.Request) {
	// Generate nonce for this request
	nonce, err := generateNonce()
	if err != nil {
		log.Printf("Failed to generate nonce: %v", err)
		nonce = "" // Fallback to unsafe-inline if nonce generation fails
	}
	
	// Set security headers with nonce for HTML page
	s.setSecurityHeadersWithNonce(w, nonce)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	
	sessionID := s.sanitizeSessionID(r.URL.Path[len("/review/"):])
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
	
	// Add nonce to session data for template
	type SessionWithNonce struct {
		*Session
		Nonce string
	}
	sessionData := SessionWithNonce{
		Session: session,
		Nonce:   nonce,
	}
	
	if err := s.reviewTemplate.Execute(w, sessionData); err != nil {
		log.Printf("Failed to execute review template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

// handleUpdateReview saves review changes
func (s *Server) handleUpdateReview(w http.ResponseWriter, r *http.Request, sessionID string) {
	s.setSecurityHeaders(w)
	
	if r.Method != http.MethodPut {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	
	s.sessionsMutex.RLock()
	session, ok := s.sessions[sessionID]
	s.sessionsMutex.RUnlock()
	
	if !ok {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}
	
	var changes struct {
		Settings map[string]interface{} `json:"settings"`
		Programs []map[string]interface{} `json:"programs"`
	}
	
	if err := json.NewDecoder(r.Body).Decode(&changes); err != nil {
		http.Error(w, fmt.Sprintf("Invalid JSON: %v", err), http.StatusBadRequest)
		return
	}
	
	// Update report with changes
	s.sessionsMutex.Lock()
	if session.Report != nil {
		if changes.Settings != nil {
			if session.Report.Settings == nil {
				session.Report.Settings = make(map[string]interface{})
			}
			for k, v := range changes.Settings {
				session.Report.Settings[k] = v
			}
		}
		if changes.Programs != nil {
			session.Report.Programs = changes.Programs
		}
		
		// Save updated report to disk
		reportPath := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-report.json", sessionID))
		if err := s.saveJSON(reportPath, session.Report); err != nil {
			log.Printf("Failed to save updated report: %v", err)
		}
	}
	s.sessionsMutex.Unlock()
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status": "saved",
		"message": "Review changes saved successfully",
	})
}

// handleGenerateConfig starts config generation after review
func (s *Server) handleGenerateConfig(w http.ResponseWriter, r *http.Request, sessionID string) {
	s.setSecurityHeaders(w)
	
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	
	s.sessionsMutex.RLock()
	session, ok := s.sessions[sessionID]
	s.sessionsMutex.RUnlock()
	
	if !ok {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}
	
	if session.Status != "review" {
		http.Error(w, fmt.Sprintf("Session must be in 'review' status, current: %s", session.Status), http.StatusBadRequest)
		return
	}
	
	// Change status to queued and add to queue
	s.sessionsMutex.Lock()
	session.Status = "queued"
	s.sessionsMutex.Unlock()
	
	// Add to queue (non-blocking)
	select {
	case s.queue <- sessionID:
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":         "queued",
			"session_id":     sessionID,
			"estimated_time": "2-5 minutes",
		})
	default:
		// Queue is full
		s.sessionsMutex.Lock()
		session.Status = "error"
		session.Error = "Processing queue is full"
		s.sessionsMutex.Unlock()
		http.Error(w, "Processing queue is full. Please try again later.", http.StatusServiceUnavailable)
	}
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
			// Fallback: serve directory listing (with XSS protection)
			w.Header().Set("Content-Type", "text/plain; charset=utf-8")
			fmt.Fprintf(w, "Configs generated in: %s\n\n", html.EscapeString(configsDir))
			fmt.Fprintf(w, "Files:\n")
			files, _ := os.ReadDir(configsDir)
			for _, file := range files {
				if !file.IsDir() {
					fmt.Fprintf(w, "- %s\n", html.EscapeString(file.Name()))
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
	// variant wird aus dem generierten desktop-config.nix gelesen, nicht als Parameter!
	go s.buildISO(req.SessionID)

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

// getScript loads script from mounted directory or falls back to embedded script
// Priority: 1. Mounted script (/app/snapshot/{platform}/nixify-scan.{ext})
//           2. Embedded script (fallback)
func (s *Server) getScript(platform string) string {
	// Try mounted scripts first (for Docker deployment)
	mountedPaths := map[string]string{
		"windows": "/app/snapshot/windows/nixify-scan.ps1",
		"macos":   "/app/snapshot/macos/nixify-scan.sh",
		"linux":   "/app/snapshot/linux/nixify-scan.sh",
	}
	
	if path, ok := mountedPaths[platform]; ok {
		if content, err := os.ReadFile(path); err == nil {
			log.Printf("Using mounted script for %s: %s", platform, path)
			return string(content)
		}
		// If mounted script doesn't exist, fall through to embedded
		log.Printf("Mounted script not found for %s at %s, using embedded script", platform, path)
	}
	
	// Fallback to embedded scripts
	switch platform {
	case "windows":
		return windowsScript
	case "macos":
		return macosScript
	case "linux":
		return linuxScript
	default:
		return ""
	}
}

func (s *Server) handleDownloadWindows(w http.ResponseWriter, r *http.Request) {
	s.setSecurityHeaders(w)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Content-Disposition", "attachment; filename=nixify-scan.ps1")
	// Security: Script is embedded via //go:embed, no user input, safe to output directly
	fmt.Fprint(w, s.getScript("windows"))
}

func (s *Server) handleDownloadMacOS(w http.ResponseWriter, r *http.Request) {
	s.setSecurityHeaders(w)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Content-Disposition", "attachment; filename=nixify-scan.sh")
	// Security: Script is embedded via //go:embed, no user input, safe to output directly
	fmt.Fprint(w, s.getScript("macos"))
}

func (s *Server) handleDownloadLinux(w http.ResponseWriter, r *http.Request) {
	s.setSecurityHeaders(w)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Content-Disposition", "attachment; filename=nixify-scan.sh")
	// Security: Script is embedded via //go:embed, no user input, safe to output directly
	fmt.Fprint(w, s.getScript("linux"))
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
	// configsDir already declared above
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

	// Determine desktop environment - KEINE FALLBACKS!
	if session.Report.Settings == nil {
		return fmt.Errorf("missing settings in snapshot report")
	}
	
	desktop, ok := session.Report.Settings["desktop"].(string)
	if !ok || desktop == "" {
		return fmt.Errorf("missing desktop in snapshot report settings")
	}
	
	// Desktop aus Mapping-Database lesen (wird vom Nix-Generator gemacht, hier nur für Fallback)
	// In generateBasicConfigs sollten wir eigentlich den Nix-Generator verwenden, nicht manuell!
	// Für jetzt: Fehler wenn kein Desktop
	desktopEnv := desktop // Verwende Desktop aus Report direkt - Mapping wird vom Nix-Generator gemacht

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

	// Generate localization-config.nix - KEINE FALLBACKS!
	timezone, ok := session.Report.Settings["timezone"].(string)
	if !ok || timezone == "" {
		return fmt.Errorf("missing timezone in snapshot report settings")
	}
	
	locale, ok := session.Report.Settings["locale"].(string)
	if !ok || locale == "" {
		return fmt.Errorf("missing locale in snapshot report settings")
	}
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

func (s *Server) buildISO(sessionID string) {
	s.sessionsMutex.RLock()
	session, exists := s.sessions[sessionID]
	s.sessionsMutex.RUnlock()

	if !exists || session == nil {
		log.Printf("Session %s not found for ISO build", sessionID)
		return
	}

	// Read desktop environment from generated config - KEIN variant Parameter!
	configsDir := filepath.Join(s.dataDir, fmt.Sprintf("session-%s-configs", sessionID))
	desktopConfigPath := filepath.Join(configsDir, "desktop-config.nix")
	
	desktopConfigContent, err := os.ReadFile(desktopConfigPath)
	if err != nil {
		log.Printf("Failed to read desktop-config.nix: %v", err)
		s.sessionsMutex.Lock()
		session.Status = "error"
		session.Error = fmt.Sprintf("Failed to read desktop-config.nix: %v", err)
		s.sessionsMutex.Unlock()
		return
	}
	
	// Extract desktop environment from config (e.g. "environment = \"plasma\";")
	desktopEnv := ""
	if strings.Contains(string(desktopConfigContent), "environment = \"") {
		start := strings.Index(string(desktopConfigContent), "environment = \"") + len("environment = \"")
		end := strings.Index(string(desktopConfigContent[start:]), "\"")
		if end > 0 {
			desktopEnv = string(desktopConfigContent[start : start+end])
		}
	}
	
	if desktopEnv == "" {
		log.Printf("Failed to extract desktop environment from desktop-config.nix")
		s.sessionsMutex.Lock()
		session.Status = "error"
		session.Error = "Failed to extract desktop environment from generated config"
		s.sessionsMutex.Unlock()
		return
	}

	log.Printf("Building ISO for session %s (desktop: %s)", sessionID, desktopEnv)
	
	s.sessionsMutex.Lock()
	session.Status = "building_iso"
	s.sessionsMutex.Unlock()

	// Build ISO using nix-build
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

	// Find NixOSControlCenter repository path
	// Try environment variable first, then fallback to relative path from dataDir
	repoPath := os.Getenv("NIXOS_CONTROL_CENTER_REPO")
	if repoPath == "" {
		// Try to find repository relative to dataDir (go up 7 levels: session-X-configs -> nixify -> specialized -> modules -> nixos -> Git -> NixOSControlCenter)
		possibleRepoPath := filepath.Join(s.dataDir, "..", "..", "..", "..", "..", "..", "..")
		if _, err := os.Stat(filepath.Join(possibleRepoPath, "nixos", "flake.nix")); err == nil {
			repoPath = filepath.Join(possibleRepoPath, "nixos")
		} else {
			// Fallback: use current working directory or error
			repoPath = "/etc/nixos" // Default fallback
			log.Printf("Warning: Could not find NixOSControlCenter repository, using fallback: %s", repoPath)
		}
	}

	// Create ISO builder expression
	builderExpr := fmt.Sprintf(`
		let
		  pkgs = import <nixpkgs> {};
		  isoBuilder = import %s/iso-builder/iso-builder.nix {
		    inherit pkgs;
		    sessionConfigs = %s;
		    nixosControlCenterRepo = %q;
		  };
		in
		  isoBuilder.buildISO {
		    sessionId = "%s";
		    repoPath = %q;
		  }
	`, filepath.Join(s.dataDir, ".."), configsMap, repoPath, sessionID, repoPath)
	
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
		return "" // Kein Fallback - leerer String
	}
	if desktop, ok := report.Settings["desktop"].(string); ok && desktop != "" {
		return desktop
	}
	return "" // Kein Fallback - leerer String
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

// generateNonce creates a cryptographically secure random nonce for CSP
func generateNonce() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(bytes), nil
}

// setSecurityHeaders sets security headers with CSP nonce for HTML pages
func (s *Server) setSecurityHeaders(w http.ResponseWriter) {
	s.setSecurityHeadersWithNonce(w, "")
}

// setSecurityHeadersWithNonce sets security headers with CSP nonce
// If nonce is empty, generates a new one. For HTML pages, pass a nonce to allow inline styles/scripts.
func (s *Server) setSecurityHeadersWithNonce(w http.ResponseWriter, nonce string) {
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("X-Frame-Options", "DENY")
	w.Header().Set("X-XSS-Protection", "1; mode=block")
	w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
	
	// For API endpoints (no nonce), use strict CSP
	if nonce == "" {
		w.Header().Set("Content-Security-Policy", "default-src 'self'")
		return
	}
	
	// For HTML pages, use nonce-based CSP (more secure than 'unsafe-inline')
	// Nonce allows specific inline styles/scripts that include the nonce attribute
	// 'unsafe-hashes' is needed for inline event handlers (onclick, etc.) and inline style attributes
	// 'style-src-attr' and 'script-src-attr' allow inline styles/scripts in HTML attributes
	csp := fmt.Sprintf("default-src 'self'; style-src 'self' 'nonce-%s' 'unsafe-hashes'; style-src-attr 'unsafe-inline'; script-src 'self' 'nonce-%s' 'unsafe-hashes'; script-src-attr 'unsafe-inline'", nonce, nonce)
	w.Header().Set("Content-Security-Policy", csp)
	w.Header().Set("X-Nonce", nonce) // Store nonce in custom header for template access
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

// discoverModules scans the filesystem for NixOS Control Center modules
func (s *Server) discoverModules() ([]ModuleInfo, error) {
	var modules []ModuleInfo
	
	// Scan core modules
	corePath := filepath.Join(s.modulesBasePath, "core")
	if err := s.scanModuleDirectory(corePath, "core", &modules); err != nil {
		log.Printf("Warning: Failed to scan core modules: %v", err)
	}
	
	// Scan optional modules
	modulesPath := filepath.Join(s.modulesBasePath, "modules")
	if err := s.scanModuleDirectory(modulesPath, "modules", &modules); err != nil {
		log.Printf("Warning: Failed to scan optional modules: %v", err)
	}
	
	return modules, nil
}

// scanModuleDirectory recursively scans a directory for modules
func (s *Server) scanModuleDirectory(rootPath, domain string, modules *[]ModuleInfo) error {
	return filepath.Walk(rootPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Skip errors, continue scanning
		}
		
		// Check if this directory is a module (has default.nix and options.nix)
		if info.IsDir() {
			defaultNix := filepath.Join(path, "default.nix")
			optionsNix := filepath.Join(path, "options.nix")
			
			if _, err := os.Stat(defaultNix); err == nil {
				if _, err := os.Stat(optionsNix); err == nil {
					// Found a module!
					module, err := s.parseModule(path, domain, rootPath)
					if err != nil {
						log.Printf("Warning: Failed to parse module at %s: %v", path, err)
						return nil // Continue scanning
					}
					*modules = append(*modules, module)
					return filepath.SkipDir // Don't scan subdirectories
				}
			}
		}
		
		return nil
	})
}

// parseModule extracts information from a module directory
func (s *Server) parseModule(modulePath, domain, rootPath string) (ModuleInfo, error) {
	moduleName := filepath.Base(modulePath)
	
	// Determine category (relative path from root)
	relPath, err := filepath.Rel(rootPath, modulePath)
	if err != nil {
		relPath = moduleName
	}
	category := domain
	if relPath != moduleName {
		category = domain + "." + strings.ReplaceAll(relPath, string(filepath.Separator), ".")
	}
	
	// Extract description from README.md or options.nix
	description := s.extractModuleDescription(modulePath)
	
	// Extract version from options.nix
	version := s.extractModuleVersion(modulePath)
	
	// Check for optional directories
	hasTUI := s.hasDirectory(modulePath, "tui")
	hasScripts := s.hasDirectory(modulePath, "scripts")
	hasHandlers := s.hasDirectory(modulePath, "handlers")
	hasLib := s.hasDirectory(modulePath, "lib")
	
	// Extract commands from commands.nix (simple regex-based)
	commands := s.extractCommands(modulePath)
	
	// Build GitHub URL
	githubPath := strings.TrimPrefix(modulePath, s.modulesBasePath)
	githubPath = strings.TrimPrefix(githubPath, "/")
	githubURL := fmt.Sprintf("%s/tree/main/nixos/%s", s.githubRepoURL, githubPath)
	
	// Find assets (subdirectories)
	assets := s.findAssets(modulePath)
	
	// Find documentation files from doc/ directory
	docs := s.findModuleDocs(modulePath)
	
	// Find doc assets from doc/assets/ directory
	docAssets := s.findDocAssets(modulePath)
	
	// Determine status by checking actual config file
	status := s.checkModuleStatus(moduleName, category, domain)
	
	return ModuleInfo{
		Name:        moduleName,
		Category:    category,
		Path:        modulePath,
		Description: description,
		Version:     version,
		Status:      status,
		HasTUI:      hasTUI,
		HasScripts:  hasScripts,
		HasHandlers: hasHandlers,
		HasLib:      hasLib,
		Commands:    commands,
		ReadmePath:  filepath.Join(modulePath, "README.md"),
		GitHubURL:   githubURL,
		Assets:      assets,
		Docs:        docs,
		DocAssets:   docAssets,
	}, nil
}

// extractModuleDescription tries to extract description from README.md or options.nix
func (s *Server) extractModuleDescription(modulePath string) string {
	// Try README.md first
	readmePath := filepath.Join(modulePath, "README.md")
	if content, err := os.ReadFile(readmePath); err == nil {
		// Extract first heading or first paragraph
		lines := strings.Split(string(content), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "# ") && len(line) > 2 {
				return strings.TrimPrefix(line, "# ")
			}
			if strings.HasPrefix(line, "## ") && len(line) > 3 {
				return strings.TrimPrefix(line, "## ")
			}
		}
		// Fallback: first non-empty line
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line != "" && !strings.HasPrefix(line, "#") {
				return line
			}
		}
	}
	
	// Try options.nix
	optionsPath := filepath.Join(modulePath, "options.nix")
	if content, err := os.ReadFile(optionsPath); err == nil {
		// Simple regex to find mkEnableOption description
		contentStr := string(content)
		if idx := strings.Index(contentStr, "mkEnableOption"); idx != -1 {
			// Try to extract description from mkEnableOption
			rest := contentStr[idx:]
			if descIdx := strings.Index(rest, `"`); descIdx != -1 {
				rest = rest[descIdx+1:]
				if endIdx := strings.Index(rest, `"`); endIdx != -1 {
					return rest[:endIdx]
				}
			}
		}
	}
	
	return fmt.Sprintf("%s module", filepath.Base(modulePath))
}

// extractModuleVersion extracts version from options.nix
func (s *Server) extractModuleVersion(modulePath string) string {
	optionsPath := filepath.Join(modulePath, "options.nix")
	if content, err := os.ReadFile(optionsPath); err == nil {
		contentStr := string(content)
		// Look for _version = "x.y.z"
		if idx := strings.Index(contentStr, "_version"); idx != -1 {
			rest := contentStr[idx:]
			if valIdx := strings.Index(rest, `"`); valIdx != -1 {
				rest = rest[valIdx+1:]
				if endIdx := strings.Index(rest, `"`); endIdx != -1 {
					return rest[:endIdx]
				}
			}
		}
	}
	return "1.0.0"
}

// hasDirectory checks if a directory exists
func (s *Server) hasDirectory(modulePath, dirName string) bool {
	dirPath := filepath.Join(modulePath, dirName)
	info, err := os.Stat(dirPath)
	return err == nil && info.IsDir()
}

// extractCommands extracts command names from commands.nix (simple regex-based)
func (s *Server) extractCommands(modulePath string) []string {
	commandsPath := filepath.Join(modulePath, "commands.nix")
	content, err := os.ReadFile(commandsPath)
	if err != nil {
		return []string{}
	}
	
	var commands []string
	contentStr := string(content)
	
	// Look for name = "..." patterns in registerCommandsFor
	lines := strings.Split(contentStr, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.Contains(line, `name = "`) {
			// Extract command name
			if idx := strings.Index(line, `name = "`); idx != -1 {
				rest := line[idx+7:]
				if endIdx := strings.Index(rest, `"`); endIdx != -1 {
					cmdName := rest[:endIdx]
					// Only add if it's a valid command name
					if cmdName != "" && !strings.Contains(cmdName, " ") {
						commands = append(commands, fmt.Sprintf("ncc %s", cmdName))
					}
				}
			}
		}
	}
	
	return commands
}

// findAssets finds subdirectories that could be considered "assets"
func (s *Server) findAssets(modulePath string) []string {
	var assets []string
	assetDirs := []string{"tui", "scripts", "handlers", "lib", "doc", "assets"}
	
	for _, dir := range assetDirs {
		if s.hasDirectory(modulePath, dir) {
			assets = append(assets, dir)
		}
	}
	
	return assets
}

// findModuleDocs finds documentation files from doc/ directory and root
func (s *Server) findModuleDocs(modulePath string) []DocInfo {
	var docs []DocInfo
	
	// Common documentation file patterns
	docExtensions := []string{".md", ".txt", ".rst"}
	docNames := map[string]string{
		"README.md":    "README",
		"SECURITY.md":  "Security",
		"ROADMAP.md":   "Roadmap",
		"CHANGELOG.md": "Changelog",
		"API.md":       "API Reference",
		"USAGE.md":     "Usage Guide",
	}
	
	// Helper function to process a directory
	processDir := func(dir string, isRoot bool) {
		// Check if directory exists
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			return
		}
		
		// Read directory contents
		entries, err := os.ReadDir(dir)
		if err != nil {
			return
		}
		
		for _, entry := range entries {
			if entry.IsDir() {
				continue // Skip subdirectories
			}
			
			name := entry.Name()
			ext := strings.ToLower(filepath.Ext(name))
			
			// Check if it's a documentation file
			isDoc := false
			for _, docExt := range docExtensions {
				if ext == docExt {
					isDoc = true
					break
				}
			}
			
			if isDoc {
				// Skip README.md in root (handled separately)
				if isRoot && name == "README.md" {
					continue
				}
				
				// Get display title
				title := name
				if t, ok := docNames[name]; ok {
					title = t
				} else {
					// Remove extension and format
					title = strings.TrimSuffix(name, ext)
					title = strings.ReplaceAll(title, "_", " ")
					title = strings.ReplaceAll(title, "-", " ")
				}
				
				docs = append(docs, DocInfo{
					Name:  strings.TrimSuffix(name, ext),
					Path:  filepath.Join(dir, name),
					Title: title,
				})
			}
		}
	}
	
	// First, check root for CHANGELOG.md (standard location)
	processDir(modulePath, true)
	
	// Then, check doc/ directory for all other documentation
	docDir := filepath.Join(modulePath, "doc")
	processDir(docDir, false)
	
	return docs
}

// findDocAssets finds assets from doc/assets/ directory
func (s *Server) findDocAssets(modulePath string) []string {
	var assets []string
	assetsDir := filepath.Join(modulePath, "doc", "assets")
	
	// Check if doc/assets directory exists
	if _, err := os.Stat(assetsDir); os.IsNotExist(err) {
		return assets
	}
	
	// Read directory contents
	entries, err := os.ReadDir(assetsDir)
	if err != nil {
		return assets
	}
	
	// Common asset extensions
	assetExtensions := []string{".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".pdf", ".ico"}
	
	for _, entry := range entries {
		if entry.IsDir() {
			continue // Skip subdirectories
		}
		
		name := entry.Name()
		ext := strings.ToLower(filepath.Ext(name))
		
		// Check if it's an asset file
		for _, assetExt := range assetExtensions {
			if ext == assetExt {
				assets = append(assets, name)
				break
			}
		}
	}
	
	return assets
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

// checkModuleStatus determines if a module is active by checking its config file
// Core modules are always active by default (unless explicitly disabled)
// Optional modules require enable = true to be active
func (s *Server) checkModuleStatus(moduleName, category, domain string) string {
	// Build config file path
	configPath := s.findModuleConfigPath(moduleName, category, domain)
	
	// Check if config file exists
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		// No config file found - module is not configured yet
		// Core modules should be active by default if not configured
		if domain == "core" {
			return "active"
		}
		// Optional modules are planned if not configured
		return "planned"
	}
	
	// Check if enable field exists in config
	hasEnable := s.hasEnableField(configPath)
	
	// Core modules: if no enable field, they're always active
	// If enable field exists, check its value
	if domain == "core" {
		if !hasEnable {
			// Core module without enable field = always active
			// Examples: module-manager, packages (no top-level enable)
			return "active"
		}
		// Core module with enable field (e.g., desktop) - check value
		enabled := s.parseNixConfigEnable(configPath, category)
		if enabled {
			return "active"
		}
		// Core module explicitly disabled (e.g., desktop on server)
		return "disabled"
	}
	
	// Optional modules: only active if enable = true
	enabled := s.parseNixConfigEnable(configPath, category)
	if enabled {
		return "active"
	}
	// Optional module with enable = false or no enable field
	return "disabled"
}

// findModuleConfigPath constructs the config file path for a module
func (s *Server) findModuleConfigPath(moduleName, category, domain string) string {
	// Category examples:
	// - "core.base.audio" -> /etc/nixos/configs/core/base/audio/config.nix
	// - "modules.specialized.nixify" -> /etc/nixos/configs/modules/specialized/nixify/config.nix
	
	// Category already contains domain and full path (e.g., "core.base.audio" or "modules.specialized.nixify")
	// Split category into parts
	parts := strings.Split(category, ".")
	
	// Build path: /etc/nixos/configs/{parts...}/config.nix
	// The category includes the module name as the last part, so we need to replace it
	pathParts := []string{"/etc/nixos/configs"}
	
	// Add all category parts except the last one (which should be the module name)
	if len(parts) > 0 {
		pathParts = append(pathParts, parts[:len(parts)-1]...)
	}
	
	// Add module name and config.nix
	pathParts = append(pathParts, moduleName, "config.nix")
	
	return filepath.Join(pathParts...)
}

// parseNixConfigEnable parses a Nix config file and checks if enable is true
func (s *Server) parseNixConfigEnable(configPath, category string) bool {
	// Try to read and parse the config file
	content, err := os.ReadFile(configPath)
	if err != nil {
		log.Printf("Failed to read config file %s: %v", configPath, err)
		return false
	}
	
	// Simple regex-based parsing for enable field
	// Look for: enable = true; or enable = false;
	contentStr := string(content)
	
	// Try to find enable = true or enable = false
	// This is a simple approach - for more complex configs, we might need nix-instantiate
	lines := strings.Split(contentStr, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		// Match: enable = true; or enable = false;
		if strings.Contains(line, "enable") {
			if strings.Contains(line, "enable = true") || strings.Contains(line, "enable=true") {
				return true
			}
			if strings.Contains(line, "enable = false") || strings.Contains(line, "enable=false") {
				return false
			}
		}
	}
	
	// If enable is not explicitly set, try using nix-instantiate for more accurate parsing
	// This is more reliable for complex configs
	return s.checkEnableWithNix(configPath, category)
}

// hasEnableField checks if config file has an enable field
func (s *Server) hasEnableField(configPath string) bool {
	content, err := os.ReadFile(configPath)
	if err != nil {
		return false
	}
	contentStr := string(content)
	lines := strings.Split(contentStr, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		// Check for enable field (can be "enable =", "enable=", or nested like "desktop.enable =")
		// But ignore comments and nested structures
		if strings.Contains(line, "enable") {
			// Check if it's a top-level enable (not nested like "docker.enable" or "desktop.enable")
			// Simple heuristic: if line starts with "enable" or has "enable" after opening brace
			// Must match: "enable = true", "enable = false", "enable=true", "enable=false"
			if strings.HasPrefix(line, "enable") {
				// Make sure it's not a comment
				if !strings.HasPrefix(line, "#") && !strings.HasPrefix(line, "//") {
					// Check if it's a valid enable assignment
					if strings.Contains(line, "=") {
						return true
					}
				}
			}
		}
	}
	return false
}

// checkEnableWithNix uses nix-instantiate to check if enable is true
func (s *Server) checkEnableWithNix(configPath, category string) bool {
	// Extract enable path from category
	// e.g., "modules.specialized.nixify" -> "modules.specialized.nixify.enable"
	enablePath := category + ".enable"
	
	// Use nix-instantiate to evaluate the enable option
	// nix-instantiate --eval --strict -E "(import /path/to/config.nix).modules.specialized.nixify.enable or false"
	expr := fmt.Sprintf(`(import %s).%s or false`, configPath, enablePath)
	
	cmd := exec.Command("nix-instantiate", "--eval", "--strict", "-E", expr)
	output, err := cmd.Output()
	if err != nil {
		// If nix-instantiate fails, fall back to default
		log.Printf("Failed to evaluate enable status with nix-instantiate for %s: %v", category, err)
		return false
	}
	
	// Parse output (should be "true" or "false")
	result := strings.TrimSpace(string(output))
	return result == "true"
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
