CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(50) PRIMARY KEY,
    username VARCHAR(64) NOT NULL UNIQUE,
    email VARCHAR(255),
    password_salt VARCHAR(128) NOT NULL,
    password_hash VARCHAR(128) NOT NULL,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    db_access_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS workspaces (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    owner_user_id VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS folders (
    id VARCHAR(50) PRIMARY KEY,
    workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(workspace_id, name)
);

CREATE TABLE IF NOT EXISTS datasets (
    id VARCHAR(50) PRIMARY KEY,
    workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    folder_id VARCHAR(50),
    name VARCHAR(255) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    data_path VARCHAR(1024) NOT NULL,
    nrow INTEGER,
    ncol INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS workspace_memberships (
    id VARCHAR(50) PRIMARY KEY,
    workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    user_id VARCHAR(50) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'viewer',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(workspace_id, user_id)
);

CREATE TABLE IF NOT EXISTS workspace_invites (
    id VARCHAR(50) PRIMARY KEY,
    workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    invited_email VARCHAR(255) NOT NULL,
    target_role VARCHAR(20) NOT NULL DEFAULT 'viewer',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_by_user_id VARCHAR(50),
    claimed_user_id VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    claimed_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(workspace_id, invited_email)
);

CREATE TABLE IF NOT EXISTS analysis_states (
    id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    workspace_id VARCHAR(50) REFERENCES workspaces(id) ON DELETE CASCADE,
    scope VARCHAR(50) NOT NULL,
    module_type VARCHAR(100) NOT NULL,
    state_name VARCHAR(255) NOT NULL,
    state_payload TEXT NOT NULL,
    state_note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_workspaces_owner_user ON workspaces(owner_user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique ON users(email);
CREATE INDEX IF NOT EXISTS idx_folders_workspace ON folders(workspace_id);
CREATE INDEX IF NOT EXISTS idx_datasets_workspace ON datasets(workspace_id);
CREATE INDEX IF NOT EXISTS idx_datasets_folder ON datasets(folder_id);
CREATE INDEX IF NOT EXISTS idx_workspace_memberships_workspace ON workspace_memberships(workspace_id);
CREATE INDEX IF NOT EXISTS idx_workspace_memberships_user ON workspace_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_workspace_invites_workspace ON workspace_invites(workspace_id);
CREATE INDEX IF NOT EXISTS idx_workspace_invites_email ON workspace_invites(invited_email);
CREATE INDEX IF NOT EXISTS idx_analysis_states_user_scope ON analysis_states(user_id, scope);
CREATE INDEX IF NOT EXISTS idx_analysis_states_workspace_module ON analysis_states(workspace_id, module_type);
CREATE UNIQUE INDEX IF NOT EXISTS uq_analysis_states_user_workspace_scope_module_name
    ON analysis_states(user_id, workspace_id, scope, module_type, state_name)
    WHERE workspace_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_analysis_states_user_scope_module_name_personal
    ON analysis_states(user_id, scope, module_type, state_name)
    WHERE workspace_id IS NULL;
