# Search & Tags System - Core Module
# Full-text search with SQLite FTS5, tag management, and categorization
{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.modules.specialized.chronicle;
  
  # Search database management
  searchDb = pkgs.writeShellScriptBin "chronicle-search-init" ''
    #!/usr/bin/env bash
    # Initialize search database with FTS5 (Full-Text Search)
    
    set -euo pipefail
    
    DB_PATH="$1"
    
    ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<'EOF'
    -- Create sessions table
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      created_at INTEGER NOT NULL,
      duration INTEGER,
      step_count INTEGER,
      category TEXT,
      metadata TEXT
    );
    
    -- Create tags table
    CREATE TABLE IF NOT EXISTS tags (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      color TEXT,
      created_at INTEGER NOT NULL
    );
    
    -- Create session_tags junction table
    CREATE TABLE IF NOT EXISTS session_tags (
      session_id TEXT NOT NULL,
      tag_id INTEGER NOT NULL,
      PRIMARY KEY (session_id, tag_id),
      FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE,
      FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
    );
    
    -- Create FTS5 virtual table for full-text search
    CREATE VIRTUAL TABLE IF NOT EXISTS sessions_fts USING fts5(
      session_id UNINDEXED,
      title,
      description,
      content,
      tokenize = 'porter unicode61'
    );
    
    -- Create categories table
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      parent_id INTEGER,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE CASCADE
    );
    
    -- Create indexes
    CREATE INDEX IF NOT EXISTS idx_sessions_created ON sessions(created_at);
    CREATE INDEX IF NOT EXISTS idx_sessions_category ON sessions(category);
    CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);
    CREATE INDEX IF NOT EXISTS idx_session_tags_session ON session_tags(session_id);
    CREATE INDEX IF NOT EXISTS idx_session_tags_tag ON session_tags(tag_id);
    
    -- Insert default categories
    INSERT OR IGNORE INTO categories (name, parent_id, created_at) VALUES
      ('Bug Report', NULL, strftime('%s', 'now')),
      ('Feature Request', NULL, strftime('%s', 'now')),
      ('Documentation', NULL, strftime('%s', 'now')),
      ('Testing', NULL, strftime('%s', 'now')),
      ('Performance', NULL, strftime('%s', 'now'));
    
    -- Insert default tags
    INSERT OR IGNORE INTO tags (name, color, created_at) VALUES
      ('critical', '#FF0000', strftime('%s', 'now')),
      ('high-priority', '#FF6600', strftime('%s', 'now')),
      ('medium', '#FFA500', strftime('%s', 'now')),
      ('low', '#00FF00', strftime('%s', 'now')),
      ('ui-bug', '#0000FF', strftime('%s', 'now')),
      ('crash', '#8B0000', strftime('%s', 'now')),
      ('regression', '#800080', strftime('%s', 'now'));
    EOF
    
    echo "Search database initialized: $DB_PATH"
  '';
  
  # Index session for search
  indexSession = pkgs.writeShellScriptBin "chronicle-index-session" ''
    #!/usr/bin/env bash
    # Index a session for full-text search
    
    set -euo pipefail
    
    SESSION_DIR="$1"
    DB_PATH="${cfg.dataDir}/search.db"
    
    # Ensure DB exists
    if [ ! -f "$DB_PATH" ]; then
      ${searchDb}/bin/chronicle-search-init "$DB_PATH"
    fi
    
    # Read session metadata
    if [ ! -f "$SESSION_DIR/metadata.json" ]; then
      echo "Error: Session metadata not found"
      exit 1
    fi
    
    SESSION_ID=$(basename "$SESSION_DIR")
    TITLE=$(${pkgs.jq}/bin/jq -r '.title // "Untitled"' "$SESSION_DIR/metadata.json")
    DESCRIPTION=$(${pkgs.jq}/bin/jq -r '.description // ""' "$SESSION_DIR/metadata.json")
    CREATED_AT=$(${pkgs.jq}/bin/jq -r '.timestamp // 0' "$SESSION_DIR/metadata.json")
    DURATION=$(${pkgs.jq}/bin/jq -r '.duration // 0' "$SESSION_DIR/metadata.json")
    STEP_COUNT=$(${pkgs.jq}/bin/jq -r '.steps | length' "$SESSION_DIR/metadata.json" 2>/dev/null || echo 0)
    
    # Extract content from steps for FTS
    CONTENT=""
    if [ -f "$SESSION_DIR/metadata.json" ]; then
      CONTENT=$(${pkgs.jq}/bin/jq -r '.steps[].title // "" | select(. != "")' "$SESSION_DIR/metadata.json" 2>/dev/null | tr '\n' ' ' || echo "")
    fi
    
    # Insert into database
    ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<EOF
    BEGIN TRANSACTION;
    
    -- Insert or replace session
    INSERT OR REPLACE INTO sessions (id, title, description, created_at, duration, step_count, category)
    VALUES ('$SESSION_ID', '$TITLE', '$DESCRIPTION', $CREATED_AT, $DURATION, $STEP_COUNT, NULL);
    
    -- Index for full-text search
    INSERT OR REPLACE INTO sessions_fts (session_id, title, description, content)
    VALUES ('$SESSION_ID', '$TITLE', '$DESCRIPTION', '$CONTENT');
    
    COMMIT;
    EOF
    
    echo "Indexed session: $SESSION_ID"
  '';
  
  # Search command
  searchCommand = pkgs.writeShellScriptBin "chronicle-search" ''
    #!/usr/bin/env bash
    # Search sessions using full-text search
    
    set -euo pipefail
    
    DB_PATH="${cfg.dataDir}/search.db"
    
    if [ ! -f "$DB_PATH" ]; then
      echo "Search database not initialized. Run 'chronicle-search-init' first."
      exit 1
    fi
    
    QUERY="''${1:-}"
    FORMAT="''${2:-table}"  # table, json, or simple
    
    if [ -z "$QUERY" ]; then
      echo "Usage: chronicle-search <query> [format]"
      echo "Format: table (default), json, simple"
      exit 1
    fi
    
    # Perform FTS search
    case "$FORMAT" in
      json)
        ${pkgs.sqlite}/bin/sqlite3 -json "$DB_PATH" <<EOF
    SELECT 
      s.id,
      s.title,
      s.description,
      s.created_at,
      s.duration,
      s.step_count,
      s.category,
      datetime(s.created_at, 'unixepoch') as created_date,
      GROUP_CONCAT(t.name, ', ') as tags
    FROM sessions s
    INNER JOIN sessions_fts fts ON s.id = fts.session_id
    LEFT JOIN session_tags st ON s.id = st.session_id
    LEFT JOIN tags t ON st.tag_id = t.id
    WHERE sessions_fts MATCH '$QUERY'
    GROUP BY s.id
    ORDER BY fts.rank;
    EOF
        ;;
      simple)
        ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<EOF
    .mode list
    SELECT s.id || ': ' || s.title
    FROM sessions s
    INNER JOIN sessions_fts fts ON s.id = fts.session_id
    WHERE sessions_fts MATCH '$QUERY'
    ORDER BY fts.rank;
    EOF
        ;;
      *)
        ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<EOF
    .mode column
    .headers on
    SELECT 
      s.id as ID,
      s.title as Title,
      datetime(s.created_at, 'unixepoch') as Created,
      s.step_count as Steps,
      GROUP_CONCAT(t.name, ', ') as Tags
    FROM sessions s
    INNER JOIN sessions_fts fts ON s.id = fts.session_id
    LEFT JOIN session_tags st ON s.id = st.session_id
    LEFT JOIN tags t ON st.tag_id = t.id
    WHERE sessions_fts MATCH '$QUERY'
    GROUP BY s.id
    ORDER BY fts.rank;
    EOF
        ;;
    esac
  '';
  
  # Tag management
  tagCommand = pkgs.writeShellScriptBin "chronicle-tag" ''
    #!/usr/bin/env bash
    # Manage session tags
    
    set -euo pipefail
    
    DB_PATH="${cfg.dataDir}/search.db"
    
    if [ ! -f "$DB_PATH" ]; then
      ${searchDb}/bin/chronicle-search-init "$DB_PATH"
    fi
    
    ACTION="''${1:-list}"
    
    case "$ACTION" in
      add)
        SESSION_ID="$2"
        TAG_NAME="$3"
        
        ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<EOF
    INSERT OR IGNORE INTO tags (name, created_at) VALUES ('$TAG_NAME', strftime('%s', 'now'));
    INSERT OR IGNORE INTO session_tags (session_id, tag_id)
    SELECT '$SESSION_ID', id FROM tags WHERE name = '$TAG_NAME';
    EOF
        echo "Added tag '$TAG_NAME' to session $SESSION_ID"
        ;;
        
      remove)
        SESSION_ID="$2"
        TAG_NAME="$3"
        
        ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<EOF
    DELETE FROM session_tags
    WHERE session_id = '$SESSION_ID'
    AND tag_id = (SELECT id FROM tags WHERE name = '$TAG_NAME');
    EOF
        echo "Removed tag '$TAG_NAME' from session $SESSION_ID"
        ;;
        
      list)
        ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<EOF
    .mode column
    .headers on
    SELECT 
      t.name as Tag,
      t.color as Color,
      COUNT(st.session_id) as Sessions,
      datetime(t.created_at, 'unixepoch') as Created
    FROM tags t
    LEFT JOIN session_tags st ON t.id = st.tag_id
    GROUP BY t.id
    ORDER BY t.name;
    EOF
        ;;
        
      create)
        TAG_NAME="$2"
        TAG_COLOR="''${3:-#808080}"
        
        ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<EOF
    INSERT OR IGNORE INTO tags (name, color, created_at)
    VALUES ('$TAG_NAME', '$TAG_COLOR', strftime('%s', 'now'));
    EOF
        echo "Created tag: $TAG_NAME ($TAG_COLOR)"
        ;;
        
      delete)
        TAG_NAME="$2"
        
        ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<EOF
    DELETE FROM tags WHERE name = '$TAG_NAME';
    EOF
        echo "Deleted tag: $TAG_NAME"
        ;;
        
      *)
        echo "Usage: chronicle-tag <action> [args]"
        echo "Actions:"
        echo "  list                    - List all tags"
        echo "  add <session> <tag>     - Add tag to session"
        echo "  remove <session> <tag>  - Remove tag from session"
        echo "  create <tag> [color]    - Create new tag"
        echo "  delete <tag>            - Delete tag"
        exit 1
        ;;
    esac
  '';
  
  # Category management
  categoryCommand = pkgs.writeShellScriptBin "chronicle-category" ''
    #!/usr/bin/env bash
    # Manage session categories
    
    set -euo pipefail
    
    DB_PATH="${cfg.dataDir}/search.db"
    
    if [ ! -f "$DB_PATH" ]; then
      ${searchDb}/bin/chronicle-search-init "$DB_PATH"
    fi
    
    ACTION="''${1:-list}"
    
    case "$ACTION" in
      set)
        SESSION_ID="$2"
        CATEGORY="$3"
        
        ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<EOF
    UPDATE sessions SET category = '$CATEGORY' WHERE id = '$SESSION_ID';
    EOF
        echo "Set category '$CATEGORY' for session $SESSION_ID"
        ;;
        
      list)
        ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<EOF
    .mode column
    .headers on
    SELECT 
      c.name as Category,
      COUNT(s.id) as Sessions
    FROM categories c
    LEFT JOIN sessions s ON c.name = s.category
    GROUP BY c.name
    ORDER BY c.name;
    EOF
        ;;
        
      sessions)
        CATEGORY="$2"
        
        ${pkgs.sqlite}/bin/sqlite3 "$DB_PATH" <<EOF
    .mode column
    .headers on
    SELECT 
      s.id as ID,
      s.title as Title,
      datetime(s.created_at, 'unixepoch') as Created,
      s.step_count as Steps
    FROM sessions s
    WHERE s.category = '$CATEGORY'
    ORDER BY s.created_at DESC;
    EOF
        ;;
        
      *)
        echo "Usage: chronicle-category <action> [args]"
        echo "Actions:"
        echo "  list                      - List all categories"
        echo "  set <session> <category>  - Set session category"
        echo "  sessions <category>       - List sessions in category"
        exit 1
        ;;
    esac
  '';
  
in
{
  # Export search utilities
  environment.systemPackages = lib.mkIf cfg.enable [
    searchDb
    indexSession
    searchCommand
    tagCommand
    categoryCommand
  ];
  
  # Auto-index sessions on creation
  systemd.services.chronicle-auto-index = lib.mkIf cfg.enable {
    description = "Auto-index Step Recorder sessions for search";
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "auto-index-sessions" ''
        #!/usr/bin/env bash
        # Auto-index all sessions
        
        DB_PATH="${cfg.dataDir}/search.db"
        
        # Initialize DB if needed
        if [ ! -f "$DB_PATH" ]; then
          ${searchDb}/bin/chronicle-search-init "$DB_PATH"
        fi
        
        # Index all sessions
        for session_dir in ${cfg.dataDir}/sessions/*; do
          if [ -d "$session_dir" ] && [ -f "$session_dir/metadata.json" ]; then
            ${indexSession}/bin/chronicle-index-session "$session_dir" || true
          fi
        done
      '';
    };
  };
  
  # Create timer for periodic re-indexing
  systemd.timers.chronicle-auto-index = lib.mkIf cfg.enable {
    description = "Periodic re-indexing of Step Recorder sessions";
    wantedBy = [ "timers.target" ];
    
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };
}
