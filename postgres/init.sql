-- Initialize AutoTFL Database Tables

-- Workspaces table
CREATE TABLE IF NOT EXISTS workspaces (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Folders table
CREATE TABLE IF NOT EXISTS folders (
    id VARCHAR(50) PRIMARY KEY,
    workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(workspace_id, name)
);

-- Datasets table
CREATE TABLE IF NOT EXISTS datasets (
    id VARCHAR(50) PRIMARY KEY,
    workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    folder_id VARCHAR(50), -- Can be NULL (root) or empty string (handled in app logic)
    name VARCHAR(255) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    data_path VARCHAR(1024) NOT NULL,
    nrow INTEGER,
    ncol INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_folders_workspace ON folders(workspace_id);
CREATE INDEX idx_datasets_workspace ON datasets(workspace_id);
CREATE INDEX idx_datasets_folder ON datasets(folder_id);
