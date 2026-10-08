-- ==============================================================================
-- CloudNotes Database Initialization Script
-- Automatically executed by PostgreSQL container entrypoint on initial volume creation
-- ==============================================================================

-- Create notes table matching JPA Note entity specification
CREATE TABLE IF NOT EXISTS notes (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for ordering notes chronologically by last modified timestamp
CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes (updated_at DESC);

-- Seed initial welcome notes if table is empty
INSERT INTO notes (title, content, created_at, updated_at)
SELECT 
    '☁️ Welcome to CloudNotes',
    'CloudNotes is running containerized on Spring Boot 3 and PostgreSQL 16. Enjoy building resilient cloud services!',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM notes);

INSERT INTO notes (title, content, created_at, updated_at)
SELECT 
    '🔒 Cloud Security & Networking',
    'In production, the PostgreSQL database is strictly isolated inside a private VPC subnet with zero public internet exposure.',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
WHERE (SELECT COUNT(*) FROM notes) <= 1;
