{ lib, pkgs }:

{
  # Dark mode CSS theme system
  darkModeCSS = ''
    /* Dark Mode Theme */
    @media (prefers-color-scheme: dark) {
      body {
        background: #1a1a1a;
        color: #e0e0e0;
      }
      
      .container {
        background: #2d2d2d;
        box-shadow: 0 2px 10px rgba(0,0,0,0.5);
      }
      
      h1 {
        color: #ffffff;
        border-bottom-color: #4a9eff;
      }
      
      .meta {
        background: #3a3a3a;
      }
      
      .meta-item {
        background: #2d2d2d;
        border-left-color: #4a9eff;
        color: #e0e0e0;
      }
      
      .step {
        border-color: #444;
        background: #2d2d2d;
      }
      
      .step-header {
        background: #1e5a9e;
      }
      
      .step-desc {
        color: #d0d0d0;
      }
      
      .screenshot img {
        border-color: #555;
      }
      
      .no-screenshot {
        background: #3a3a2d;
        border-color: #8a7a4a;
        color: #e0d090;
      }
      
      .footer {
        color: #888;
      }
      
      /* Gallery dark mode */
      .gallery-grid {
        background: #2d2d2d;
      }
      
      .gallery-item {
        background: #3a3a3a;
        border-color: #555;
      }
      
      .gallery-item:hover {
        border-color: #4a9eff;
        box-shadow: 0 4px 15px rgba(74, 158, 255, 0.3);
      }
      
      /* Timeline dark mode */
      .timeline {
        background: #2d2d2d;
      }
      
      .timeline-axis {
        background: #444;
      }
      
      .timeline-item {
        background: #3a3a3a;
        border-color: #555;
      }
      
      .timeline-item:hover {
        background: #454545;
      }
    }
    
    /* Manual dark mode toggle */
    body.dark-theme {
      background: #1a1a1a;
      color: #e0e0e0;
    }
    
    body.dark-theme .container {
      background: #2d2d2d;
      box-shadow: 0 2px 10px rgba(0,0,0,0.5);
    }
    
    body.dark-theme h1 {
      color: #ffffff;
      border-bottom-color: #4a9eff;
    }
    
    body.dark-theme .meta {
      background: #3a3a3a;
    }
    
    body.dark-theme .meta-item {
      background: #2d2d2d;
      border-left-color: #4a9eff;
      color: #e0e0e0;
    }
    
    body.dark-theme .step {
      border-color: #444;
      background: #2d2d2d;
    }
    
    body.dark-theme .step-header {
      background: #1e5a9e;
    }
    
    body.dark-theme .step-desc {
      color: #d0d0d0;
    }
    
    body.dark-theme .screenshot img {
      border-color: #555;
    }
    
    body.dark-theme .no-screenshot {
      background: #3a3a2d;
      border-color: #8a7a4a;
      color: #e0d090;
    }
    
    body.dark-theme .footer {
      color: #888;
    }
  '';
  
  # Theme toggle button HTML/JS
  themeToggleButton = ''
    <button id="theme-toggle" class="theme-toggle" onclick="toggleTheme()" title="Toggle Dark Mode">
      <span class="theme-icon">🌙</span>
    </button>
    
    <style>
      .theme-toggle {
        position: fixed;
        top: 20px;
        right: 20px;
        background: #007bff;
        border: none;
        border-radius: 50%;
        width: 50px;
        height: 50px;
        cursor: pointer;
        font-size: 24px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.2);
        transition: transform 0.2s, background 0.2s;
        z-index: 100;
      }
      
      .theme-toggle:hover {
        transform: scale(1.1);
        background: #0056b3;
      }
      
      body.dark-theme .theme-toggle {
        background: #4a9eff;
      }
      
      body.dark-theme .theme-icon::before {
        content: '☀️';
      }
    </style>
    
    <script>
      // Theme management
      function toggleTheme() {
        const body = document.body;
        const isDark = body.classList.toggle('dark-theme');
        localStorage.setItem('theme', isDark ? 'dark' : 'light');
        updateThemeIcon(isDark);
      }
      
      function updateThemeIcon(isDark) {
        const icon = document.querySelector('.theme-icon');
        icon.textContent = isDark ? '☀️' : '🌙';
      }
      
      // Detect system theme preference
      function detectSystemTheme() {
        return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
      }
      
      // Initialize theme on page load
      document.addEventListener('DOMContentLoaded', function() {
        const savedTheme = localStorage.getItem('theme');
        const prefersDark = detectSystemTheme();
        
        if (savedTheme === 'dark' || (!savedTheme && prefersDark)) {
          document.body.classList.add('dark-theme');
          updateThemeIcon(true);
        }
        
        // Listen for system theme changes
        if (window.matchMedia) {
          window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
            if (!localStorage.getItem('theme')) {
              document.body.classList.toggle('dark-theme', e.matches);
              updateThemeIcon(e.matches);
            }
          });
        }
      });
    </script>
  '';
  
  # Function to inject dark mode into HTML exports
  injectDarkMode = { htmlFile }: ''
    inject_dark_mode() {
      local html_file="${htmlFile}"
      
      # Check if file exists
      if [ ! -f "$html_file" ]; then
        log "HTML file not found: $html_file"
        return 1
      fi
      
      # Create temporary file
      local tmp_file=$(mktemp)
      
      # Inject dark mode CSS and toggle button
      ${pkgs.gnused}/bin/sed '/<\/style>/r'<(cat << 'DARKMODE_CSS'
${darkModeCSS}
DARKMODE_CSS
) "$html_file" > "$tmp_file"
      
      # Inject theme toggle button before closing body tag
      ${pkgs.gnused}/bin/sed -i '/<\/body>/i ${themeToggleButton}' "$tmp_file"
      
      # Replace original file
      mv "$tmp_file" "$html_file"
      
      log "Dark mode injected into: $html_file"
    }
  '';
}
