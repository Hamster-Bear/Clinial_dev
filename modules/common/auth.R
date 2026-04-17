`%||%` <- function(x, y) if (is.null(x)) y else x

auth_empty_registry <- function() {
  list(
    workspaces = data.frame(
      id = character(0),
      name = character(0),
      owner_user_id = character(0),
      created_at = as.POSIXct(character(0)),
      stringsAsFactors = FALSE
    ),
    folders = data.frame(
      id = character(0),
      workspace_id = character(0),
      name = character(0),
      created_at = as.POSIXct(character(0)),
      stringsAsFactors = FALSE
    ),
    datasets = data.frame(
      id = character(0),
      workspace_id = character(0),
      folder_id = character(0),
      name = character(0),
      file_name = character(0),
      data_path = character(0),
      nrow = numeric(0),
      ncol = numeric(0),
      created_at = as.POSIXct(character(0)),
      stringsAsFactors = FALSE
    )
  )
}

auth_generate_id <- function(prefix) {
  paste0(prefix, "_", as.integer(as.numeric(Sys.time())), "_", sample(1000:9999, 1))
}

auth_normalize_username <- function(username) {
  tolower(trimws(username %||% ""))
}

auth_normalize_email <- function(email) {
  tolower(trimws(email %||% ""))
}

auth_validate_username <- function(username) {
  normalized <- auth_normalize_username(username)
  if (!nzchar(normalized)) {
    return("请输入用户名")
  }
  if (!grepl("^[a-z0-9_.-]{3,32}$", normalized)) {
    return("用户名仅支持 3-32 位小写字母、数字、下划线、点和中划线")
  }
  NULL
}

auth_validate_email <- function(email) {
  normalized <- auth_normalize_email(email)
  if (!nzchar(normalized)) {
    return("请输入邮箱")
  }
  if (!grepl("^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$", normalized, ignore.case = TRUE)) {
    return("邮箱格式不正确")
  }
  NULL
}

auth_validate_password <- function(password) {
  password <- password %||% ""
  if (!nzchar(password)) {
    return("请输入密码")
  }
  if (nchar(password) < 8) {
    return("密码至少需要 8 位")
  }
  NULL
}

auth_generate_salt <- function() {
  digest::digest(
    paste(Sys.time(), runif(1), sample(c(letters, LETTERS, 0:9), 16, replace = TRUE), collapse = "|"),
    algo = "sha256",
    serialize = FALSE
  )
}

auth_hash_password <- function(password, salt) {
  digest::digest(
    paste0(salt, "::", password %||% ""),
    algo = "sha256",
    serialize = FALSE
  )
}

auth_verify_password <- function(password, salt, expected_hash) {
  identical(auth_hash_password(password, salt), expected_hash)
}

auth_create_pool <- function() {
  pool::dbPool(
    drv = RPostgres::Postgres(),
    dbname = Sys.getenv("POSTGRES_DB", "autotfl"),
    host = Sys.getenv("POSTGRES_HOST", "localhost"),
    port = as.integer(Sys.getenv("POSTGRES_PORT", "5432")),
    user = Sys.getenv("POSTGRES_USER", "autotfl_user"),
    password = Sys.getenv("POSTGRES_PASSWORD", "ChangeMe123!")
  )
}

auth_migrate_analysis_states_schema <- function(pool) {
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS workspace_id VARCHAR(50)")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS scope VARCHAR(50)")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS module_type VARCHAR(100)")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS state_name VARCHAR(255)")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS state_payload TEXT")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS state_note TEXT")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ALTER COLUMN state_payload TYPE TEXT USING state_payload::text")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ALTER COLUMN state_note TYPE TEXT USING state_note::text")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP")
  DBI::dbExecute(pool, "ALTER TABLE analysis_states ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP")
  DBI::dbExecute(
    pool,
    paste(
      "UPDATE analysis_states",
      "SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP),",
      "created_at = COALESCE(created_at, updated_at, CURRENT_TIMESTAMP)"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "DO $$",
      "BEGIN",
      "  IF NOT EXISTS (",
      "    SELECT 1",
      "    FROM pg_constraint",
      "    WHERE conrelid = 'analysis_states'::regclass",
      "      AND conname = 'analysis_states_workspace_fk'",
      "  ) THEN",
      "    ALTER TABLE analysis_states",
      "    ADD CONSTRAINT analysis_states_workspace_fk",
      "    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE;",
      "  END IF;",
      "END $$;"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "DO $$",
      "DECLARE rec RECORD;",
      "BEGIN",
      "  FOR rec IN",
      "    SELECT conname",
      "    FROM pg_constraint",
      "    WHERE conrelid = 'analysis_states'::regclass",
      "      AND contype = 'u'",
      "  LOOP",
      "    EXECUTE format('ALTER TABLE analysis_states DROP CONSTRAINT IF EXISTS %I', rec.conname);",
      "  END LOOP;",
      "END $$;"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "WITH ranked AS (",
      "  SELECT ctid,",
      "         ROW_NUMBER() OVER (",
      "           PARTITION BY user_id, workspace_id, scope, module_type, state_name",
      "           ORDER BY COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) DESC, created_at DESC, id DESC",
      "         ) AS rn",
      "  FROM analysis_states",
      "  WHERE workspace_id IS NOT NULL",
      "    AND COALESCE(BTRIM(scope), '') <> ''",
      "    AND COALESCE(BTRIM(module_type), '') <> ''",
      "    AND COALESCE(BTRIM(state_name), '') <> ''",
      ")",
      "DELETE FROM analysis_states target",
      "USING ranked",
      "WHERE target.ctid = ranked.ctid AND ranked.rn > 1"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "WITH ranked AS (",
      "  SELECT ctid,",
      "         ROW_NUMBER() OVER (",
      "           PARTITION BY user_id, scope, module_type, state_name",
      "           ORDER BY COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) DESC, created_at DESC, id DESC",
      "         ) AS rn",
      "  FROM analysis_states",
      "  WHERE workspace_id IS NULL",
      "    AND COALESCE(BTRIM(scope), '') <> ''",
      "    AND COALESCE(BTRIM(module_type), '') <> ''",
      "    AND COALESCE(BTRIM(state_name), '') <> ''",
      ")",
      "DELETE FROM analysis_states target",
      "USING ranked",
      "WHERE target.ctid = ranked.ctid AND ranked.rn > 1"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE UNIQUE INDEX IF NOT EXISTS uq_analysis_states_user_workspace_scope_module_name",
      "ON analysis_states(user_id, workspace_id, scope, module_type, state_name)",
      "WHERE workspace_id IS NOT NULL",
      "  AND COALESCE(BTRIM(scope), '') <> ''",
      "  AND COALESCE(BTRIM(module_type), '') <> ''",
      "  AND COALESCE(BTRIM(state_name), '') <> ''"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE UNIQUE INDEX IF NOT EXISTS uq_analysis_states_user_scope_module_name_personal",
      "ON analysis_states(user_id, scope, module_type, state_name)",
      "WHERE workspace_id IS NULL",
      "  AND COALESCE(BTRIM(scope), '') <> ''",
      "  AND COALESCE(BTRIM(module_type), '') <> ''",
      "  AND COALESCE(BTRIM(state_name), '') <> ''"
    )
  )
}

auth_ensure_schema <- function(pool) {
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS workspaces (",
      "id VARCHAR(50) PRIMARY KEY,",
      "name VARCHAR(255) NOT NULL,",
      "owner_user_id VARCHAR(50),",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS folders (",
      "id VARCHAR(50) PRIMARY KEY,",
      "workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,",
      "name VARCHAR(255) NOT NULL,",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,",
      "UNIQUE(workspace_id, name)",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS datasets (",
      "id VARCHAR(50) PRIMARY KEY,",
      "workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,",
      "folder_id VARCHAR(50),",
      "name VARCHAR(255) NOT NULL,",
      "file_name VARCHAR(255) NOT NULL,",
      "data_path VARCHAR(1024) NOT NULL,",
      "nrow INTEGER,",
      "ncol INTEGER,",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS users (",
      "id VARCHAR(50) PRIMARY KEY,",
      "username VARCHAR(64) NOT NULL UNIQUE,",
      "email VARCHAR(255),",
      "password_salt VARCHAR(128) NOT NULL,",
      "password_hash VARCHAR(128) NOT NULL,",
      "is_admin BOOLEAN NOT NULL DEFAULT FALSE,",
      "db_access_enabled BOOLEAN NOT NULL DEFAULT FALSE,",
      "status VARCHAR(20) NOT NULL DEFAULT 'active',",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    "ALTER TABLE workspaces ADD COLUMN IF NOT EXISTS owner_user_id VARCHAR(50)"
  )
  DBI::dbExecute(
    pool,
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255)"
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS workspace_memberships (",
      "id VARCHAR(50) PRIMARY KEY,",
      "workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,",
      "user_id VARCHAR(50) NOT NULL REFERENCES users(id) ON DELETE CASCADE,",
      "role VARCHAR(20) NOT NULL DEFAULT 'viewer',",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,",
      "UNIQUE(workspace_id, user_id)",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS workspace_invites (",
      "id VARCHAR(50) PRIMARY KEY,",
      "workspace_id VARCHAR(50) NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,",
      "invited_email VARCHAR(255) NOT NULL,",
      "target_role VARCHAR(20) NOT NULL DEFAULT 'viewer',",
      "status VARCHAR(20) NOT NULL DEFAULT 'pending',",
      "created_by_user_id VARCHAR(50),",
      "claimed_user_id VARCHAR(50),",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,",
      "claimed_at TIMESTAMP WITH TIME ZONE,",
      "UNIQUE(workspace_id, invited_email)",
      ")"
    )
  )
  DBI::dbExecute(
    pool,
    paste(
      "CREATE TABLE IF NOT EXISTS analysis_states (",
      "id VARCHAR(50) PRIMARY KEY,",
      "user_id VARCHAR(50) NOT NULL REFERENCES users(id) ON DELETE CASCADE,",
      "workspace_id VARCHAR(50) REFERENCES workspaces(id) ON DELETE CASCADE,",
      "scope VARCHAR(50) NOT NULL,",
      "module_type VARCHAR(100) NOT NULL,",
      "state_name VARCHAR(255) NOT NULL,",
      "state_payload TEXT NOT NULL,",
      "state_note TEXT,",
      "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,",
      "updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP",
      ")"
    )
  )
  auth_migrate_analysis_states_schema(pool)
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_workspaces_owner_user ON workspaces(owner_user_id)")
  DBI::dbExecute(pool, "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique ON users(email)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_folders_workspace ON folders(workspace_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_datasets_workspace ON datasets(workspace_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_datasets_folder ON datasets(folder_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_workspace_memberships_workspace ON workspace_memberships(workspace_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_workspace_memberships_user ON workspace_memberships(user_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_workspace_invites_workspace ON workspace_invites(workspace_id)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_workspace_invites_email ON workspace_invites(invited_email)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_analysis_states_user_scope ON analysis_states(user_id, scope)")
  DBI::dbExecute(pool, "CREATE INDEX IF NOT EXISTS idx_analysis_states_workspace_module ON analysis_states(workspace_id, module_type)")
}

auth_get_user_by_username <- function(pool, username) {
  normalized <- auth_normalize_username(username)
  if (!nzchar(normalized)) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    pool,
    "SELECT * FROM users WHERE username = $1 LIMIT 1",
    params = list(normalized)
  )
}

auth_get_user_by_email <- function(pool, email) {
  normalized <- auth_normalize_email(email)
  if (!nzchar(normalized)) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    pool,
    "SELECT * FROM users WHERE email = $1 LIMIT 1",
    params = list(normalized)
  )
}

auth_get_user_by_identity <- function(pool, identity) {
  normalized <- trimws(identity %||% "")
  if (!nzchar(normalized)) {
    return(data.frame())
  }
  if (grepl("@", normalized, fixed = TRUE)) {
    return(auth_get_user_by_email(pool, normalized))
  }
  auth_get_user_by_username(pool, normalized)
}

auth_get_user_by_id <- function(pool, user_id) {
  if (is.null(user_id) || !nzchar(user_id)) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    pool,
    "SELECT * FROM users WHERE id = $1 LIMIT 1",
    params = list(user_id)
  )
}

auth_list_users <- function(pool) {
  DBI::dbGetQuery(pool, "SELECT * FROM users ORDER BY created_at ASC")
}

auth_build_user_payload <- function(user_row) {
  if (is.null(user_row) || !is.data.frame(user_row) || nrow(user_row) == 0) {
    return(NULL)
  }
  list(
    id = user_row$id[[1]],
    username = user_row$username[[1]],
    email = if (is.null(user_row$email[[1]]) || is.na(user_row$email[[1]])) "" else user_row$email[[1]],
    is_admin = isTRUE(user_row$is_admin[[1]]),
    db_access_enabled = isTRUE(user_row$db_access_enabled[[1]]) || isTRUE(user_row$is_admin[[1]])
  )
}

auth_register_user <- function(pool, username, email, password) {
  username_error <- auth_validate_username(username)
  if (!is.null(username_error)) {
    return(list(success = FALSE, message = username_error, user = NULL))
  }
  email_error <- auth_validate_email(email)
  if (!is.null(email_error)) {
    return(list(success = FALSE, message = email_error, user = NULL))
  }
  password_error <- auth_validate_password(password)
  if (!is.null(password_error)) {
    return(list(success = FALSE, message = password_error, user = NULL))
  }
  normalized <- auth_normalize_username(username)
  normalized_email <- auth_normalize_email(email)
  existing <- auth_get_user_by_username(pool, normalized)
  if (nrow(existing) > 0) {
    return(list(success = FALSE, message = "用户名已存在", user = NULL))
  }
  email_existing <- auth_get_user_by_email(pool, normalized_email)
  if (nrow(email_existing) > 0) {
    return(list(success = FALSE, message = "邮箱已被使用", user = NULL))
  }
  all_users <- auth_list_users(pool)
  should_grant_admin <- nrow(all_users) == 0 || !any(all_users$is_admin %in% TRUE)
  user_id <- auth_generate_id("usr")
  salt <- auth_generate_salt()
  password_hash <- auth_hash_password(password, salt)
  DBI::dbExecute(
    pool,
    paste(
      "INSERT INTO users (id, username, email, password_salt, password_hash, is_admin, db_access_enabled, status, created_at)",
      "VALUES ($1, $2, $3, $4, $5, $6, $7, 'active', NOW())"
    ),
    params = list(user_id, normalized, normalized_email, salt, password_hash, should_grant_admin, FALSE)
  )
  created <- auth_get_user_by_id(pool, user_id)
  list(
    success = TRUE,
    message = if (should_grant_admin) "注册成功，当前账号已成为系统管理员" else "注册成功，请登录",
    user = auth_build_user_payload(created)
  )
}

auth_authenticate_user <- function(pool, identity, password) {
  user_row <- auth_get_user_by_identity(pool, identity)
  if (nrow(user_row) == 0) {
    return(list(success = FALSE, message = "用户名或密码错误", user = NULL))
  }
  if (!identical(user_row$status[[1]], "active")) {
    return(list(success = FALSE, message = "账号已停用", user = NULL))
  }
  if (!auth_verify_password(password, user_row$password_salt[[1]], user_row$password_hash[[1]])) {
    return(list(success = FALSE, message = "用户名或密码错误", user = NULL))
  }
  list(success = TRUE, message = "登录成功", user = auth_build_user_payload(user_row))
}

auth_ensure_bootstrap_admin <- function(pool) {
  username <- auth_normalize_username(Sys.getenv("APP_ADMIN_USERNAME", ""))
  email <- auth_normalize_email(Sys.getenv("APP_ADMIN_EMAIL", ""))
  password <- Sys.getenv("APP_ADMIN_PASSWORD", "")
  if (!nzchar(username) || !nzchar(password)) {
    return(invisible(NULL))
  }
  existing <- auth_get_user_by_username(pool, username)
  if (nrow(existing) > 0) {
    return(invisible(NULL))
  }
  if (nzchar(email)) {
    email_error <- auth_validate_email(email)
    if (!is.null(email_error)) {
      return(invisible(NULL))
    }
    existing_email <- auth_get_user_by_email(pool, email)
    if (nrow(existing_email) > 0) {
      return(invisible(NULL))
    }
  } else {
    email <- NULL
  }
  password_error <- auth_validate_password(password)
  if (!is.null(password_error)) {
    return(invisible(NULL))
  }
  salt <- auth_generate_salt()
  DBI::dbExecute(
    pool,
    paste(
      "INSERT INTO users (id, username, email, password_salt, password_hash, is_admin, db_access_enabled, status, created_at)",
      "VALUES ($1, $2, $3, $4, $5, TRUE, TRUE, 'active', NOW())"
    ),
    params = list(auth_generate_id("usr"), username, email, salt, auth_hash_password(password, salt))
  )
  invisible(NULL)
}

auth_ensure_workspace_membership <- function(pool, workspace_id, user_id, role = "owner") {
  if (is.null(workspace_id) || !nzchar(workspace_id) || is.null(user_id) || !nzchar(user_id)) {
    return(invisible(FALSE))
  }
  DBI::dbExecute(
    pool,
    paste(
      "INSERT INTO workspace_memberships (id, workspace_id, user_id, role, created_at)",
      "VALUES ($1, $2, $3, $4, NOW())",
      "ON CONFLICT (workspace_id, user_id) DO UPDATE SET role = EXCLUDED.role"
    ),
    params = list(auth_generate_id("wsm"), workspace_id, user_id, role)
  )
  invisible(TRUE)
}

auth_filter_registry <- function(reg, workspace_ids, is_admin = FALSE) {
  if (isTRUE(is_admin)) {
    return(reg)
  }
  workspace_ids <- unique(workspace_ids %||% character(0))
  if (length(workspace_ids) == 0) {
    return(auth_empty_registry())
  }
  workspaces <- reg$workspaces[reg$workspaces$id %in% workspace_ids, , drop = FALSE]
  folders <- reg$folders[reg$folders$workspace_id %in% workspace_ids, , drop = FALSE]
  datasets <- reg$datasets[reg$datasets$workspace_id %in% workspace_ids, , drop = FALSE]
  list(workspaces = workspaces, folders = folders, datasets = datasets)
}

auth_accessible_workspace_ids <- function(pool, user_id, is_admin = FALSE) {
  if (isTRUE(is_admin)) {
    rows <- DBI::dbGetQuery(pool, "SELECT id FROM workspaces")
    return(unique(rows$id %||% character(0)))
  }
  if (is.null(user_id) || !nzchar(user_id)) {
    return(character(0))
  }
  owned <- DBI::dbGetQuery(
    pool,
    "SELECT id FROM workspaces WHERE owner_user_id = $1",
    params = list(user_id)
  )
  member <- DBI::dbGetQuery(
    pool,
    "SELECT workspace_id FROM workspace_memberships WHERE user_id = $1",
    params = list(user_id)
  )
  unique(c(owned$id %||% character(0), member$workspace_id %||% character(0)))
}

auth_user_can_access_workspace <- function(pool, user_id, is_admin = FALSE, workspace_id) {
  if (is.null(workspace_id) || !nzchar(workspace_id)) {
    return(FALSE)
  }
  workspace_id %in% auth_accessible_workspace_ids(pool, user_id, is_admin)
}

auth_load_registry <- function(pool, user_id = NULL, is_admin = FALSE) {
  reg <- tryCatch(
    list(
      workspaces = DBI::dbGetQuery(pool, "SELECT * FROM workspaces ORDER BY created_at DESC"),
      folders = DBI::dbGetQuery(pool, "SELECT * FROM folders ORDER BY created_at DESC"),
      datasets = DBI::dbGetQuery(pool, "SELECT * FROM datasets ORDER BY created_at DESC")
    ),
    error = function(e) auth_empty_registry()
  )
  if (isTRUE(is_admin)) {
    return(reg)
  }
  auth_filter_registry(reg, auth_accessible_workspace_ids(pool, user_id, is_admin = FALSE), is_admin = FALSE)
}
