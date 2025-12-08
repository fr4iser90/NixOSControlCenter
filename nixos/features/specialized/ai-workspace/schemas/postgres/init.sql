-- Basis-Schema für Code-Management
CREATE TABLE IF NOT EXISTS code_snippets (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    language TEXT,
    file_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    embedding_id VARCHAR(100),
    metadata JSONB
);

-- Index für schnellere Suche
CREATE INDEX IF NOT EXISTS idx_code_snippets_language ON code_snippets(language);
CREATE INDEX IF NOT EXISTS idx_code_snippets_embedding ON code_snippets(embedding_id);